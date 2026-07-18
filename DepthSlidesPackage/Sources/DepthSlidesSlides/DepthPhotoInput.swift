import CoreGraphics
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// `loadTransferable(type: Data.self)` を要求させると Photos が JPEG に
/// 変換して深度メタデータを剥がしてしまうため、HEIC のまま（ファイル→データの順で）
/// 取得できるよう明示的な UTType で要求する。`DepthImagePickerView` と
/// `DepthModelPickerView` の両方から利用する共通ヘルパー。
func originalImageData(from item: PhotosPickerItem) async -> Data? {
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

/// 深度マップ・元画像はセンサーの生の向きで格納されていることがあるため、
/// 本体画像の EXIF Orientation を読み取って同じ回転を適用する必要がある。
func exifOrientation(from source: CGImageSource) -> CGImagePropertyOrientation? {
  guard
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
    let raw = properties[kCGImagePropertyOrientation] as? UInt32,
    let orientation = CGImagePropertyOrientation(rawValue: raw),
    orientation != .up
  else { return nil }
  return orientation
}

/// Photos が保持しているオリジナルの HEIC ファイルを（コピーして）そのまま受け取る。
struct HEICFileTransferable: Transferable {
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
struct HEICTransferable: Transferable {
  let data: Data
  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(importedContentType: .heic) { HEICTransferable(data: $0) }
  }
}
