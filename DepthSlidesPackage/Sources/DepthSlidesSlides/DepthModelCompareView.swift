import CoreImage
import ImageIO
import MarkdownToSlide
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 登壇中に実際の写真を選び、複数の Core ML 深度推定モデルを切り替えながら
/// 元画像とのビフォーアフター比較（ドラッグで見え隠れ・ピンチズーム）ができる
/// スライド向けView。開発用の簡易デモ `DepthModelPickerView` とは別に、
/// 本番のスライドで使う機能（ファイル選択・セグメントコントロール・
/// ズーム・キャッシュ）をまとめて持つ。
struct DepthModelCompareView: View {
  @Environment(\.slideTheme) var slideTheme

  @State private var pickerItem: PhotosPickerItem?
  @State private var isFileImporterPresented = false
  @State private var selectedModel: DepthModel = .depthAnythingV2Small

  @State private var imageData: Data?
  @State private var originalCGImage: CGImage?
  @State private var depthCGImage: CGImage?
  @State private var statusMessage = "写真を選んでください"

  @State private var zoomState = ImageZoomState.identity
  @State private var revealFraction: CGFloat = 0.5

  private let context = CIContext()

  var body: some View {
    VStack(spacing: 16) {
      ZStack {
        RoundedRectangle(cornerRadius: 12)
          .fill(.black.opacity(0.03))

        if let originalCGImage, let depthCGImage {
          BeforeAfterImageCompareView(
            before: originalCGImage,
            after: depthCGImage,
            zoomState: $zoomState,
            revealFraction: $revealFraction
          )
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
      .pickerStyle(.segmented)

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
    .onChange(of: selectedModel) { _, _ in
      Task { await runEstimation() }
    }
  }

  // MARK: - 画像の読み込み

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

  /// Photos・ファイルどちらの経路も、最終的にこの1箇所で同じデコード処理に収束させる。
  /// 新しい画像が選ばれたタイミングでのみズーム・比較スライダーの位置をリセットする
  /// （モデルを切り替えたときは `onChange(of: selectedModel)` 側でリセットしないため保持される）。
  private func loadImage(from data: Data) async {
    depthCGImage = nil
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
    revealFraction = 0.5

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

    guard selectedModel.packageURL != nil else {
      depthCGImage = nil
      statusMessage =
        "\(selectedModel.displayName) のモデルが見つかりません。scripts/ 以下のスクリプトを実行してください"
      return
    }

    depthCGImage = nil
    statusMessage = "\(selectedModel.displayName) で推論中..."

    let cacheKey = DepthCacheKey(imageData: imageData, model: selectedModel)
    do {
      let result = try await DepthEstimator.shared.estimateCached(
        cgImage: originalCGImage, model: selectedModel, cacheKey: cacheKey)
      depthCGImage = result
    } catch {
      statusMessage = "推論に失敗しました: \(error)"
    }
  }
}

#Preview {
  DepthModelCompareView()
    .padding()
}
