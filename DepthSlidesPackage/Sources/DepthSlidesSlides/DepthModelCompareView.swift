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
  private enum DisplayMode: String, CaseIterable, Identifiable {
    case compare, blur, conversionCode, code

    var id: String { rawValue }

    var displayName: String {
      switch self {
      case .compare: "深度比較"
      case .blur: "ボケ適用"
      case .conversionCode: "モデル変換コード"
      case .code: "コード"
      }
    }
  }

  @Environment(\.slideTheme) var slideTheme

  @State private var pickerItem: PhotosPickerItem?
  @State private var isFileImporterPresented = false
  @State private var isPeerCaptureCameraPresented = false
  @State private var isPeerReceiverPresented = false
  @State private var selectedModel: DepthModel = .embeddedDepth
  @State private var displayMode: DisplayMode = .compare

  @State private var imageData: Data?
  @State private var originalCGImage: CGImage?
  @State private var depthCGImage: CGImage?
  @State private var blurredCGImage: CGImage?
  @State private var focusPoint: CGPoint?
  @State private var statusMessage = "写真を選んでください"

  @State private var zoomState = ImageZoomState.identity
  @State private var revealFraction: CGFloat = 0.5
  @State private var blurZoomState = ImageZoomState.identity

  private let context = CIContext()
  private let converter = MarkdownToSlideConverter()

  var body: some View {
    VStack(spacing: 16) {
      ZStack(alignment: .topTrailing) {
        RoundedRectangle(cornerRadius: 12)
          .fill(.black.opacity(0.03))

        contentView

        // 他のボタンと並べた行の中だと押しにくいという指摘を受け、コーナーに
        // 独立したフローティングボタンとして配置している（SlideNavigationView の
        // 「Export PDF」ボタンと同じ見た目・置き方）。
        #if os(iOS)
          Button {
            isPeerCaptureCameraPresented = true
          } label: {
            Image(systemName: "camera.badge.ellipsis")
              .font(.system(size: 20))
          }
          .buttonStyle(.glass)
          .padding(12)
        #elseif os(macOS)
          Button {
            isPeerReceiverPresented = true
          } label: {
            Image(systemName: "iphone.and.arrow.forward")
              .font(.system(size: 20))
          }
          .buttonStyle(.glass)
          .padding(12)
        #endif
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      Picker("表示モード", selection: $displayMode) {
        ForEach(DisplayMode.allCases) { mode in
          Text(mode.displayName).tag(mode)
        }
      }
      .pickerStyle(.segmented)

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
    #if os(iOS)
      .fullScreenCover(isPresented: $isPeerCaptureCameraPresented) {
        PeerCaptureCameraView { data in
          isPeerCaptureCameraPresented = false
          Task { await loadImage(from: data) }
        }
      }
    #elseif os(macOS)
      .sheet(isPresented: $isPeerReceiverPresented) {
        PeerCaptureReceiverView { data in
          isPeerReceiverPresented = false
          Task { await loadImage(from: data) }
        }
      }
    #endif
  }

  @ViewBuilder
  private var contentView: some View {
    switch displayMode {
    case .compare:
      if let originalCGImage, let depthCGImage {
        BeforeAfterImageCompareView(
          before: originalCGImage,
          after: depthCGImage,
          zoomState: $zoomState,
          revealFraction: $revealFraction
        )
        .padding(8)
      } else {
        statusText
      }
    case .blur:
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
          // 「元画像 vs ボケ適用後」を見え隠れスライダーで比較する方式は、
          // タップした位置が今どちらのレイヤーの上にあるのか分かりにくく
          // 混乱を招いたため、ボケ適用後の結果画像だけを表示するシンプルな
          // 構成に変更している（元画像との比較は既存の「深度比較」モードで代用可能）。
          ZoomableFocusableImageView(
            image: blurredCGImage,
            onTap: { point in
              focusPoint = point
              Task { await recomputeBlur() }
            },
            zoomState: $blurZoomState
          )
        }
        .padding(8)
      } else {
        statusText
      }
    case .conversionCode:
      ScrollView {
        converter.convertPage(selectedModel.conversionMarkdown)
      }
    case .code:
      ScrollView {
        converter.convertPage(codeMarkdown)
      }
    }
  }

  private var statusText: some View {
    Text(statusMessage)
      .font(.system(size: 28))
      .foregroundStyle(slideTheme.secondaryTextColor)
      .multilineTextAlignment(.center)
      .padding()
  }

  private var codeMarkdown: String {
    """
    ### \(selectedModel.codeSectionTitle)

    ```swift
    \(selectedModel.estimationCodeSample)
    ```

    ### 共通のボケ適用処理

    ```swift
    \(DepthBokehBlur.sampleCode)
    ```
    """
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
    revealFraction = 0.5
    blurZoomState = .identity
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

    if selectedModel == .embeddedDepth {
      statusMessage = "写真に含まれる深度情報を抽出中..."
      do {
        let result = try await Task.detached(priority: .userInitiated) {
          try EmbeddedDepthExtractor.extractDepthImage(from: imageData)
        }.value
        depthCGImage = result
        await recomputeBlur()
      } catch EmbeddedDepthExtractor.ExtractionError.noEmbeddedDepthData {
        statusMessage = "この写真には深度情報が含まれていません（Portraitモードで撮影した写真をお試しください）"
      } catch {
        statusMessage = "深度情報の抽出に失敗しました: \(error)"
      }
      return
    }

    guard selectedModel.packageURL != nil else {
      statusMessage =
        "\(selectedModel.displayName) のモデルが見つかりません。scripts/ 以下のスクリプトを実行してください"
      return
    }

    statusMessage = "\(selectedModel.displayName) で推論中..."

    let cacheKey = DepthCacheKey(imageData: imageData, model: selectedModel)
    do {
      let result = try await DepthEstimator.shared.estimateCached(
        cgImage: originalCGImage, model: selectedModel, cacheKey: cacheKey)
      depthCGImage = result

      // ボケモードに切り替えたときに待ち時間なしで表示できるよう、深度が
      // 確定した時点で続けて計算しておく。
      await recomputeBlur()
    } catch {
      statusMessage = "推論に失敗しました: \(error)"
    }
  }

  /// `originalCGImage`/`depthCGImage`/`focusPoint`（タップでピントを指定した場合）
  /// から `blurredCGImage` を計算し直す。モデル切り替え後の再推論後と、
  /// ユーザーが画像をタップしてピント位置を変更したときの両方から呼ばれる。
  private func recomputeBlur() async {
    guard let originalCGImage, let depthCGImage else { return }
    // Task.detached のクロージャに actor-isolated な @State を直接キャプチャさせない
    // よう、呼び出し前にローカル定数へスナップショットしておく。
    let focusPoint = focusPoint
    // GPU処理だが念のため MainActor をブロックしないよう Task.detached にしている。
    blurredCGImage = await Task.detached(priority: .userInitiated) {
      DepthBokehBlur.apply(original: originalCGImage, depth: depthCGImage, focusPoint: focusPoint)
    }.value
  }
}

#Preview {
  DepthModelCompareView()
    .padding()
}
