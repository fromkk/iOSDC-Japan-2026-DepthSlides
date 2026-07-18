import AVFoundation
import CoreImage
import ImageIO
import MarkdownToSlide
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// PhotosPicker で選んだ HEIF 写真から AVDepthData を取り出し、
/// 深度画像（disparity マップ）をその場でプレビューするための View。
/// 登壇中にライブで写真を選んで深度画像を見せられるよう対話的に保つ。
struct DepthImagePickerView: View {
  @Environment(\.slideTheme) var slideTheme
  @State private var pickerItem: PhotosPickerItem?
  @State private var depthCGImage: CGImage?
  @State private var statusMessage: String = "Portraitモードで撮影した写真を選んでください"

  private let context = CIContext()

  var body: some View {
    VStack(spacing: 16) {
      ZStack {
        RoundedRectangle(cornerRadius: 12)
          .fill(.black.opacity(0.03))

        if let depthCGImage {
          Image(decorative: depthCGImage, scale: 1)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(8)
        } else {
          Text(statusMessage)
            .font(.system(size: 28))
            .foregroundStyle(slideTheme.secondaryTextColor)
            .multilineTextAlignment(.center)
            .padding()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      PhotosPicker(selection: $pickerItem, matching: .images) {
        Label("HEIF 写真を選択", systemImage: "photo.badge.plus")
          .font(.system(size: 28))
      }
    }
    .onChange(of: pickerItem) { _, newItem in
      Task { await loadDepthImage(from: newItem) }
    }
  }

  private func loadDepthImage(from item: PhotosPickerItem?) async {
    guard let item else { return }
    depthCGImage = nil
    statusMessage = "読み込み中..."

    guard let data = await originalImageData(from: item),
      let source = CGImageSourceCreateWithData(data as CFData, nil)
    else {
      statusMessage = "写真を読み込めませんでした"
      return
    }

    guard
      let depthData = auxiliaryDepthData(from: source)
    else {
      statusMessage = "この写真には深度情報が含まれていません"
      return
    }

    let converted = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
    var depthImage = CIImage(cvPixelBuffer: converted.depthDataMap)

    // 深度マップはセンサーの生の向きで格納されているため、本体画像の EXIF
    // Orientation を読み取って同じ回転を適用しないと縦写真が横向きになる。
    if let orientation = exifOrientation(from: source) {
      depthImage = depthImage.oriented(orientation)
    }

    guard let cgImage = context.createCGImage(depthImage, from: depthImage.extent) else {
      statusMessage = "深度画像の生成に失敗しました"
      return
    }

    depthCGImage = cgImage
  }

  /// `loadTransferable(type: Data.self)` request させると Photos が JPEG に
  /// 変換して深度メタデータを剥がしてしまうため、HEIC のまま（ファイル→データの順で）
  /// 取得できるよう明示的な UTType で要求する。
  private func originalImageData(from item: PhotosPickerItem) async -> Data? {
    if let file = try? await item.loadTransferable(type: HEICFileTransferable.self) {
      defer { try? FileManager.default.removeItem(at: file.url) }
      if let data = try? Data(contentsOf: file.url) {
        return data
      }
    }
    if let heic = try? await item.loadTransferable(type: HEICTransferable.self) {
      return heic.data
    }
    return try? await item.loadTransferable(type: Data.self)
  }

  private func auxiliaryDepthData(from source: CGImageSource) -> AVDepthData? {
    for auxType in [kCGImageAuxiliaryDataTypeDepth, kCGImageAuxiliaryDataTypeDisparity]
      as [CFString]
    {
      guard
        let info = CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, auxType)
          as? [AnyHashable: Any],
        let depthData = try? AVDepthData(fromDictionaryRepresentation: info)
      else { continue }
      return depthData
    }
    return nil
  }

  private func exifOrientation(from source: CGImageSource) -> CGImagePropertyOrientation? {
    guard
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let raw = properties[kCGImagePropertyOrientation] as? UInt32,
      let orientation = CGImagePropertyOrientation(rawValue: raw),
      orientation != .up
    else { return nil }
    return orientation
  }
}

/// Photos が保持しているオリジナルの HEIC ファイルを（コピーして）そのまま受け取る。
private struct HEICFileTransferable: Transferable {
  let url: URL
  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .heic) { received in
      let dest = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".heic")
      try FileManager.default.copyItem(at: received.file, to: dest)
      return HEICFileTransferable(url: dest)
    }
  }
}

/// HEIC を明示的な UTType 付きで要求し、深度メタデータの欠落を防ぐ。
private struct HEICTransferable: Transferable {
  let data: Data
  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(importedContentType: .heic) { HEICTransferable(data: $0) }
  }
}

#Preview {
  DepthImagePickerView()
    .padding()
}
