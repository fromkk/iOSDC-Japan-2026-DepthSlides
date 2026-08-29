import CoreImage
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 深度推定モデルは Depth Anything V2 Small に固定し、7種類の Core Image
/// ブラー系フィルター（`BokehFilterKind`）を切り替えながら、フィルターごとの
/// パラメーターを調整してボケの見た目を比較するスライド向けView。
/// 写真読み込み・向き補正のロジックは `DepthModelCompareView` と共通の
/// `DepthPhotoInput.swift` のヘルパーを再利用する。
///
/// 現在スライド本編では使っていない（結果を並べて見せる
/// `BokehFilterResultGridView` に差し替えた）が、質疑などでその場で
/// パラメーターを触りたくなったとき用に残してある。
struct CIFilterBokehCompareView: View {
  @Environment(\.slideTheme) var slideTheme

  @State private var pickerItem: PhotosPickerItem?
  @State private var isFileImporterPresented = false
  @State private var selectedFilter: BokehFilterKind = .maskedVariableBlur
  @State private var parameters = BokehFilterParameters()

  @State private var imageData: Data?
  @State private var originalCGImage: CGImage?
  @State private var depthCGImage: CGImage?
  @State private var blurredCGImage: CGImage?
  @State private var focusPoint: CGPoint?
  @State private var statusMessage = "写真を選んでください"

  @State private var zoomState = ImageZoomState.identity

  private let context = CIContext()

  var body: some View {
    VStack(spacing: 16) {
      ZStack {
        RoundedRectangle(cornerRadius: 12)
          .fill(.black.opacity(0.03))

        contentView
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      Picker("フィルター", selection: $selectedFilter) {
        ForEach(BokehFilterKind.allCases) { filter in
          Text(filter.displayName).tag(filter)
        }
      }
      .pickerStyle(.menu)

      parameterSliders

      HStack(spacing: 12) {
        PhotosPicker(selection: $pickerItem, matching: .images) {
          Label("写真ライブラリから選択", systemImage: "photo.badge.plus")
            .font(.system(size: 22))
        }

        Button {
          isFileImporterPresented = true
        } label: {
          Label("ファイルから選択", systemImage: "folder.badge.plus")
            .font(.system(size: 22))
        }
      }
    }
    .fileImporter(
      isPresented: $isFileImporterPresented,
      allowedContentTypes: [.image]
    ) { result in
      Task { await handleFileImporterResult(result) }
    }
    .onChange(of: pickerItem) { _, newItem in
      Task { await loadFromPhotosPicker(newItem) }
    }
    .onChange(of: selectedFilter) { _, _ in
      Task { await recomputeBlur() }
    }
    .onChange(of: parameters) { _, _ in
      Task { await recomputeBlur() }
    }
  }

  @ViewBuilder
  private var contentView: some View {
    if let blurredCGImage {
      VStack(spacing: 4) {
        HStack {
          Text("画像をタップしてピントを合わせられます")
            .font(.system(size: 14))
            .foregroundStyle(slideTheme.secondaryTextColor)
          if focusPoint != nil {
            Button("ピントをリセット") {
              focusPoint = nil
              Task { await recomputeBlur() }
            }
            .font(.system(size: 14))
          }
        }
        ZoomableFocusableImageView(
          image: blurredCGImage,
          onTap: { point in
            focusPoint = point
            Task { await recomputeBlur() }
          },
          zoomState: $zoomState
        )
      }
      .padding(8)
    } else {
      statusText
    }
  }

  private var statusText: some View {
    Text(statusMessage)
      .font(.system(size: 28))
      .foregroundStyle(slideTheme.secondaryTextColor)
      .multilineTextAlignment(.center)
      .padding()
  }

  // MARK: - フィルターごとのパラメータースライダー

  @ViewBuilder
  private var parameterSliders: some View {
    switch selectedFilter {
    case .boxBlur, .discBlur, .gaussianBlur, .maskedVariableBlur:
      LabeledSlider(label: "半径", value: $parameters.radius, range: 0...50)
    case .zoomBlur:
      LabeledSlider(label: "強さ", value: $parameters.amount, range: 0...100)
    case .motionBlur:
      HStack(spacing: 16) {
        LabeledSlider(label: "半径", value: $parameters.radius, range: 0...50)
        LabeledSlider(
          label: "角度", value: $parameters.angle, range: 0...(2 * .pi),
          format: { String(format: "%.0f°", $0 * 180 / .pi) })
      }
    case .bokehBlur:
      VStack(spacing: 8) {
        HStack(spacing: 16) {
          LabeledSlider(label: "半径", value: $parameters.radius, range: 0...50)
          LabeledSlider(
            label: "リング量", value: $parameters.ringAmount, range: 0...1,
            format: { String(format: "%.2f", $0) })
        }
        HStack(spacing: 16) {
          LabeledSlider(
            label: "リングサイズ", value: $parameters.ringSize, range: 0...1,
            format: { String(format: "%.2f", $0) })
          LabeledSlider(
            label: "ソフトネス", value: $parameters.softness, range: 0...1,
            format: { String(format: "%.2f", $0) })
        }
      }
    }
  }

  // MARK: - 画像の読み込み（DepthModelCompareView と同じ手順）

  private func loadFromPhotosPicker(_ item: PhotosPickerItem?) async {
    guard let item else { return }
    guard let data = await originalImageData(from: item) else {
      statusMessage = "写真を読み込めませんでした"
      return
    }
    await loadImage(from: data)
  }

  private func handleFileImporterResult(_ result: Result<URL, Error>) async {
    switch result {
    case .failure(let error):
      statusMessage = "ファイルを読み込めませんでした: \(error)"
    case .success(let url):
      let didStartAccessing = url.startAccessingSecurityScopedResource()
      defer {
        if didStartAccessing { url.stopAccessingSecurityScopedResource() }
      }
      guard let data = try? Data(contentsOf: url) else {
        statusMessage = "ファイルを読み込めませんでした"
        return
      }
      await loadImage(from: data)
    }
  }

  private func loadImage(from data: Data) async {
    depthCGImage = nil
    blurredCGImage = nil
    statusMessage = "読み込み中..."

    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
      statusMessage = "写真を読み込めませんでした"
      return
    }

    let oriented = orientedCGImage(decoded, orientation: exifOrientation(from: source))

    imageData = data
    originalCGImage = oriented
    zoomState = .identity
    focusPoint = nil

    await runEstimation()
  }

  private func orientedCGImage(_ cgImage: CGImage, orientation: CGImagePropertyOrientation?)
    -> CGImage
  {
    guard let orientation else { return cgImage }
    let ciImage = CIImage(cgImage: cgImage).oriented(orientation)
    return context.createCGImage(ciImage, from: ciImage.extent) ?? cgImage
  }

  // MARK: - 推論

  private func runEstimation() async {
    guard let originalCGImage, let imageData else { return }

    depthCGImage = nil
    blurredCGImage = nil

    guard DepthModel.depthAnythingV2Small.packageURL != nil else {
      statusMessage =
        "\(DepthModel.depthAnythingV2Small.displayName) のモデルが見つかりません。scripts/ 以下のスクリプトを実行してください"
      return
    }

    statusMessage = "\(DepthModel.depthAnythingV2Small.displayName) で推論中..."

    let cacheKey = DepthCacheKey(imageData: imageData, model: .depthAnythingV2Small)
    do {
      let result = try await DepthEstimator.shared.estimateCached(
        cgImage: originalCGImage, model: .depthAnythingV2Small, cacheKey: cacheKey)
      depthCGImage = result
      await recomputeBlur()
    } catch {
      statusMessage = "推論に失敗しました: \(error)"
    }
  }

  /// `originalCGImage`/`depthCGImage`/`selectedFilter`/`parameters`/`focusPoint`
  /// から `blurredCGImage` を計算し直す。
  private func recomputeBlur() async {
    guard let originalCGImage, let depthCGImage else { return }
    let filter = selectedFilter
    let parameters = parameters
    let focusPoint = focusPoint
    blurredCGImage = await Task.detached(priority: .userInitiated) {
      CIFilterBokehBlur.apply(
        original: originalCGImage, depth: depthCGImage, filter: filter,
        parameters: parameters, focusPoint: focusPoint)
    }.value
  }
}

#Preview {
  CIFilterBokehCompareView()
    .padding()
}
