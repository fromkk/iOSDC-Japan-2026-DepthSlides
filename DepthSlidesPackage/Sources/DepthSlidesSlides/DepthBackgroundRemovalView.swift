import CoreImage
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 深度推定モデルは Depth Anything V2 Small に固定し、画像上でタップした
/// オブジェクトより手前だけを残して背景を削除するデモ用 View。
/// `CIFilterBokehCompareView` からフィルター選択・パラメーター UI を取り除き、
/// 「タップ → 選択位置の深度より奥を透過」に絞った構成。写真読み込みの手順は
/// `DepthPhotoInput.swift` の共通ヘルパーを再利用する。
struct DepthBackgroundRemovalView: View {
  @Environment(\.slideTheme) var slideTheme

  @State private var pickerItem: PhotosPickerItem?
  @State private var isFileImporterPresented = false

  @State private var imageData: Data?
  @State private var originalCGImage: CGImage?
  @State private var depthCGImage: CGImage?
  @State private var resultCGImage: CGImage?
  @State private var selectionPoint: CGPoint?
  @State private var statusMessage = "写真を選んでください"
  /// 深度推定中かどうか。`true` の間は画像の上にローディングを重ね、タップを無効にする。
  @State private var isEstimating = false

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
  }

  @ViewBuilder
  private var contentView: some View {
    if let displayedImage {
      VStack(spacing: 4) {
        HStack {
          Text(headerMessage)
          .font(.system(size: 14))
          .foregroundStyle(slideTheme.secondaryTextColor)
          if selectionPoint != nil {
            Button("選択をリセット") {
              selectionPoint = nil
              resultCGImage = nil
            }
            .font(.system(size: 14))
          }
        }
        ZoomableFocusableImageView(
          image: displayedImage,
          onTap: depthCGImage == nil
            ? nil
            : { point in
              selectionPoint = point
              Task { await recomputeRemoval() }
            },
          zoomState: $zoomState
        )
        .overlay {
          if isEstimating {
            estimatingOverlay
          }
        }
      }
      .padding(8)
    } else {
      statusText
    }
  }

  /// 選択前は元画像、選択後は背景削除後の画像を表示する。
  private var displayedImage: CGImage? {
    resultCGImage ?? originalCGImage
  }

  private var headerMessage: String {
    if isEstimating {
      return "深度を推定中です。完了すると画像をタップできるようになります"
    }
    if depthCGImage == nil {
      return statusMessage
    }
    return selectionPoint == nil
      ? "画像をタップして残したいオブジェクトを選んでください"
      : "選んだオブジェクトより奥を背景として削除しました（市松模様 = 透過）"
  }

  /// 推定中に画像の上へ重ねるローディング表示。モデルのコンパイル・ロード・
  /// 推論のどの段階かを `statusMessage` で示す。
  private var estimatingOverlay: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12)
        .fill(.black.opacity(0.45))
      VStack(spacing: 16) {
        ProgressView()
          .controlSize(.large)
          .tint(.white)
        Text(statusMessage)
          .font(.system(size: 22, weight: .medium))
          .foregroundStyle(.white)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
      }
    }
    .allowsHitTesting(false)
  }

  private var statusText: some View {
    Text(statusMessage)
      .font(.system(size: 28))
      .foregroundStyle(slideTheme.secondaryTextColor)
      .multilineTextAlignment(.center)
      .padding()
  }

  // MARK: - 画像の読み込み（CIFilterBokehCompareView と同じ手順）

  private func loadFromPhotosPicker(_ item: PhotosPickerItem?) async {
    guard let item else { return }
    guard let data = await originalImageData(from: item) else {
      statusMessage = "写真を読み込めませんでした"
      return
    }
    await loadImage(from: data)
  }

  private func handleFileImporterResult(_ result: Result<URL, any Error>) async {
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
    resultCGImage = nil
    selectionPoint = nil
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

    guard DepthModel.depthAnythingV2Small.packageURL != nil else {
      statusMessage =
        "\(DepthModel.depthAnythingV2Small.displayName) のモデルが見つかりません。scripts/ 以下のスクリプトを実行してください"
      return
    }

    let model = DepthModel.depthAnythingV2Small
    isEstimating = true
    // 途中で別の写真に切り替わっていたら、その写真の推定が表示を管理する。
    defer { if imageData == self.imageData { isEstimating = false } }
    statusMessage = "\(model.displayName) の推論を準備中..."

    let cacheKey = DepthCacheKey(imageData: imageData, model: model)
    do {
      let result = try await DepthEstimator.shared.estimateCached(
        cgImage: originalCGImage, model: model, cacheKey: cacheKey
      ) { phase in
        // await 中に別の写真へ切り替わっていたら、古いフェーズ表示で上書きしない。
        guard imageData == self.imageData else { return }
        switch phase {
        case .compilingModel:
          statusMessage = "\(model.displayName) のモデルをコンパイル中...（初回のみ）"
        case .loadingModel:
          statusMessage =
            "\(model.displayName) のモデルを読み込み中...（この端末での初回は数分かかることがあります）"
        case .inferring:
          statusMessage = "\(model.displayName) で推論中..."
        }
      }
      guard imageData == self.imageData else { return }
      depthCGImage = result
    } catch {
      statusMessage = "推論に失敗しました: \(error)"
    }
  }

  /// `originalCGImage`/`depthCGImage`/`selectionPoint` から `resultCGImage` を計算し直す。
  private func recomputeRemoval() async {
    guard let originalCGImage, let depthCGImage, let selectionPoint else {
      resultCGImage = nil
      return
    }
    resultCGImage = await Task.detached(priority: .userInitiated) {
      DepthBackgroundRemoval.apply(
        original: originalCGImage, depth: depthCGImage, selectionPoint: selectionPoint)
    }.value
  }
}

#Preview {
  DepthBackgroundRemovalView()
    .padding()
}
