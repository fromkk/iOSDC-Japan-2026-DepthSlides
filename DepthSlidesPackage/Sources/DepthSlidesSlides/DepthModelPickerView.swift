import CoreImage
import ImageIO
import MarkdownToSlide
import PhotosUI
import SwiftUI

/// PhotosPicker で選んだ写真に対して、選択した Core ML 深度推定モデルで
/// 推論を実行し、その場で深度画像をプレビューするための View。
/// `DepthImagePickerView`（AVDepthData版）と同じ UX パターンを踏襲しつつ、
/// モデルを切り替えて比較できるようにしている。
struct DepthModelPickerView: View {
  @Environment(\.slideTheme) var slideTheme
  @State private var pickerItem: PhotosPickerItem?
  @State private var selectedModel: DepthModel = .depthAnythingV2Small
  @State private var depthCGImage: CGImage?
  @State private var statusMessage: String = "写真を選んでください"

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

      Picker("モデル", selection: $selectedModel) {
        ForEach(DepthModel.availableCases) { model in
          Text(model.displayName).tag(model)
        }
      }
      .pickerStyle(.menu)

      PhotosPicker(selection: $pickerItem, matching: .images) {
        Label("写真を選択", systemImage: "photo.badge.plus")
          .font(.system(size: 28))
      }
    }
    .onChange(of: pickerItem) { _, newItem in
      Task { await runEstimation(for: newItem) }
    }
    .onChange(of: selectedModel) { _, _ in
      Task { await runEstimation(for: pickerItem) }
    }
  }

  private func runEstimation(for item: PhotosPickerItem?) async {
    guard let item else { return }
    depthCGImage = nil

    guard selectedModel.packageURL != nil else {
      statusMessage =
        "\(selectedModel.displayName) のモデルが見つかりません。scripts/ 以下のスクリプトを実行してください"
      return
    }

    statusMessage = "読み込み中..."
    guard let data = await originalImageData(from: item),
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
      statusMessage = "写真を読み込めませんでした"
      return
    }

    let inputImage = orientedCGImage(decoded, orientation: exifOrientation(from: source))

    statusMessage = "\(selectedModel.displayName) で推論中..."
    do {
      let result = try await DepthEstimator.shared.estimate(
        cgImage: inputImage, model: selectedModel)
      depthCGImage = result
    } catch {
      statusMessage = "推論に失敗しました: \(error)"
    }
  }

  /// 元画像は EXIF Orientation を反映しない生のピクセルデータで取得されるため、
  /// モデルに渡す前に本体画像の向きを補正する（深度データ側の補正は
  /// `DepthImagePickerView` と同じ考え方）。
  private func orientedCGImage(_ cgImage: CGImage, orientation: CGImagePropertyOrientation?)
    -> CGImage
  {
    guard let orientation else { return cgImage }
    let oriented = CIImage(cgImage: cgImage).oriented(orientation)
    return context.createCGImage(oriented, from: oriented.extent) ?? cgImage
  }
}

#Preview {
  DepthModelPickerView()
    .padding()
}
