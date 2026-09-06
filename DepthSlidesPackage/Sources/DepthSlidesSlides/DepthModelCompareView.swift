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

  /// 新しい写真を選んだときに、選択中以外のモデルの推論を裏で直列に進めておくタスク。
  /// 次の写真が選ばれたら古いプリフェッチはキャンセルして置き換える。
  @State private var prefetchTask: Task<Void, Never>?

  /// 選択中モデルの推論（`runEstimation`）を実行中のタスク。モデルを切り替えたり
  /// 画面から離れたりしたときに、actor のキューで順番待ちしている古い推論を
  /// キャンセルして無駄に走らせないために保持する。
  @State private var estimationTask: Task<Void, Never>?

  /// 現在の写真に対して推論結果がまだ用意できていないモデルの集合。
  /// モデル選択のセグメント名の横にインジケーターを表示するのに使う。
  @State private var inferringModels: Set<DepthModel> = []

  private let context = CIContext()
  private let converter = MarkdownToSlideConverter()

  var body: some View {
    VStack(spacing: 16) {
      ZStack {
        RoundedRectangle(cornerRadius: 12)
          .fill(.black.opacity(0.03))

        contentView
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
          // セグメント内では任意のViewはもちろん、Text に補間した SF Symbol も
          // 描画されない（検証済み）ため、Unicode 文字でインジケーターを表現する。
          if inferringModels.contains(model) {
            Text("\(model.displayName) ⏳").tag(model)
          } else {
            Text(model.displayName).tag(model)
          }
        }
      }
      .pickerStyle(.segmented)

      // 素のラベルだけだと当たり判定が文字の幅しかなく、スライド表示で縮小される
      // と押しにくかったため、横幅いっぱいの大きな枠付きボタンにしている。
      // 以前は写真エリア右上に小さなフローティングボタンとして置いていた
      // iPhone 撮影／受信のボタンも、同じ理由でこの列にまとめた。
      HStack(spacing: 16) {
        PhotosPicker(selection: $pickerItem, matching: .images) {
          pickerButtonLabel("写真ライブラリから選択", systemImage: "photo.badge.plus")
        }

        Button {
          isFileImporterPresented = true
        } label: {
          pickerButtonLabel("ファイルから選択", systemImage: "folder.badge.plus")
        }

        #if os(iOS)
          Button {
            isPeerCaptureCameraPresented = true
          } label: {
            pickerButtonLabel("このiPhoneで撮影", systemImage: "camera.badge.ellipsis")
          }
        #elseif os(macOS)
          Button {
            isPeerReceiverPresented = true
          } label: {
            pickerButtonLabel("iPhoneから受信", systemImage: "iphone.and.arrow.forward")
          }
        #endif
      }
      .buttonStyle(.bordered)
      .controlSize(.extraLarge)
      .tint(slideTheme.primaryTextColor)
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
      estimationTask?.cancel()
      estimationTask = Task { await runEstimation() }
    }
    .onDisappear {
      // スライドから離れたら、順番待ちの推論（特に最重量の depthPro）を
      // 開始させない。すでに実行中の1件の `MLModel.prediction` は同期実行の
      // ため中断できず、それだけは完走する。
      prefetchTask?.cancel()
      prefetchTask = nil
      estimationTask?.cancel()
      estimationTask = nil
    }
    #if os(iOS)
      .fullScreenCover(isPresented: $isPeerCaptureCameraPresented) {
        PeerCaptureCameraView { data in
          isPeerCaptureCameraPresented = false
          Task { await loadImage(from: data) }
        }
      }
    #elseif os(macOS)
      // sheet だとウィンドウサイズに関係なく小さな窓（480×360 程度）になり、
      // 会場のスクリーンでは iPhone のライブプレビューが豆粒にしか見えなかった。
      // スライド本体の上に重ねる形にして、スライド領域いっぱいに表示する。
      .overlay {
        if isPeerReceiverPresented {
          PeerCaptureReceiverView(
            onReceived: { data in
              isPeerReceiverPresented = false
              Task { await loadImage(from: data) }
            },
            onClose: { isPeerReceiverPresented = false }
          )
          .background(slideTheme.backgroundColor)
          .clipShape(RoundedRectangle(cornerRadius: 12))
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

  /// 写真選択ボタンの中身。`contentShape` を含めてボタン全体を押せる領域にする。
  nonisolated private func pickerButtonLabel(_ title: String, systemImage: String) -> some View {
    Label(title, systemImage: systemImage)
      .font(.system(size: 26, weight: .semibold))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .contentShape(Rectangle())
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
    prefetchTask?.cancel()
    prefetchTask = nil
    estimationTask?.cancel()
    estimationTask = nil

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

    // 今回の写真で推論対象となる全モデル（選択中モデル + プリフェッチ対象）を
    // 「未完了」として登録する。完了するたびに各処理側で取り除く。
    var pending = Set(
      DepthModel.availableCases.filter { $0 != .embeddedDepth && $0.packageURL != nil })
    pending.insert(selectedModel)
    inferringModels = pending

    // 画面から離れたときにキャンセルできるよう `estimationTask` として保持しつつ、
    // プリフェッチより先に選択中モデルの推論が終わるのを待つ。
    let task = Task { await runEstimation() }
    estimationTask = task
    await task.value

    // 選択中モデルの推論が終わってから残りのモデルを裏で直列にプリフェッチする
    // （actor のキュー順で選択中モデルが必ず先に処理されるようにするため）。
    let selected = selectedModel
    prefetchTask = Task {
      await prefetchRemainingModels(imageData: data, cgImage: oriented, excluding: selected)
    }
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

    // await 中にモデルや写真が切り替わった場合、古い結果で表示を上書きしない
    // ようにするためのスナップショット。
    let model = selectedModel
    let cacheKey = DepthCacheKey(imageData: imageData, model: model)

    // キャッシュ済みなら actor（推論キュー）を経由せず同期的に取り出して即表示する。
    // `estimateCached` の中にもキャッシュ判定はあるが、actor がプリフェッチ中の
    // 別モデルの推論で塞がっているとその判定まで待たされてしまうため、
    // ここで先に引くことに意味がある。
    if let cached = DepthEstimator.shared.cachedDepthImage(for: cacheKey) {
      finishInferring(model, for: imageData)
      depthCGImage = cached
      await recomputeBlur()
      return
    }

    if model == .embeddedDepth {
      statusMessage = "写真に埋め込まれた深度情報を抽出中..."
      do {
        let result = try await Task.detached(priority: .userInitiated) {
          try EmbeddedDepthExtractor.extractDepthImage(from: imageData)
        }.value
        DepthEstimator.shared.storeDepthImage(result, for: cacheKey)
        finishInferring(model, for: imageData)
        guard model == selectedModel, imageData == self.imageData else { return }
        depthCGImage = result
        await recomputeBlur()
      } catch EmbeddedDepthExtractor.ExtractionError.noEmbeddedDepthData {
        finishInferring(model, for: imageData)
        guard model == selectedModel, imageData == self.imageData else { return }
        statusMessage = "この写真には深度情報が含まれていません（Portraitモードで撮影した写真をお試しください）"
      } catch {
        finishInferring(model, for: imageData)
        guard model == selectedModel, imageData == self.imageData else { return }
        statusMessage = "深度情報の抽出に失敗しました: \(error)"
      }
      return
    }

    guard model.packageURL != nil else {
      finishInferring(model, for: imageData)
      statusMessage =
        "\(model.displayName) のモデルが見つかりません。scripts/ 以下のスクリプトを実行してください"
      return
    }

    // actor がプリフェッチ中の別モデルの推論で塞がっている間は onPhase が
    // 呼ばれないため、順番待ちの間はこの表示のままになる。
    statusMessage = "\(model.displayName) の推論を準備中...（他のモデルの処理待ちの場合があります）"

    do {
      let result = try await DepthEstimator.shared.estimateCached(
        cgImage: originalCGImage, model: model, cacheKey: cacheKey
      ) { phase in
        // await 中に別のモデル・写真へ切り替わっていたら、古いフェーズ表示で
        // 上書きしない。
        guard model == selectedModel, imageData == self.imageData else { return }
        switch phase {
        case .compilingModel:
          statusMessage = "\(model.displayName) のモデルをコンパイル中...（初回のみ）"
        case .loadingModel:
          statusMessage = "\(model.displayName) のモデルを読み込み中...（この端末での初回は数分かかることがあります）"
        case .inferring:
          statusMessage = "\(model.displayName) で推論中..."
        }
      }
      finishInferring(model, for: imageData)
      guard model == selectedModel, imageData == self.imageData else { return }
      depthCGImage = result

      // ボケモードに切り替えたときに待ち時間なしで表示できるよう、深度が
      // 確定した時点で続けて計算しておく。
      await recomputeBlur()
    } catch is CancellationError {
      // 画面から離れた・モデルや写真を切り替えた等で不要になった推論。
      // 表示はキャンセルした側が引き継ぐため、ここでは何もしない。
      return
    } catch {
      finishInferring(model, for: imageData)
      guard model == selectedModel, imageData == self.imageData else { return }
      statusMessage = "推論に失敗しました: \(error)"
    }
  }

  /// 対象の写真が今も表示中の場合のみ、モデルの推論完了を記録してインジケーターを消す。
  /// await 中に別の写真へ切り替わっていた場合は、新しい写真の未完了状態を壊さない。
  private func finishInferring(_ model: DepthModel, for imageData: Data) {
    guard imageData == self.imageData else { return }
    inferringModels.remove(model)
  }

  /// 選択中のモデル以外の各モデルの推論を裏で直列に進め、あとでモデルを
  /// 切り替えたときにキャッシュヒットで即座に表示できるようにする。
  /// `DepthEstimator` は actor で推論本体が同期実行のため、1つの Task 内で
  /// 順番に await するだけで直列になる。選択中のモデルは `runEstimation()` が
  /// 担当するため除外する。表示には `inferringModels` の更新以外では触れない。
  private func prefetchRemainingModels(
    imageData: Data, cgImage: CGImage, excluding selected: DepthModel
  ) async {
    // depthPro（macOS のみ・最重量）はプリフェッチ中のモデル切り替えを
    // 待たせる時間が長くなるため最後に回す。
    var targets = DepthModel.availableCases.filter {
      $0 != .embeddedDepth && $0 != selected && $0.packageURL != nil
    }
    if let index = targets.firstIndex(of: .depthPro) {
      targets.append(targets.remove(at: index))
    }

    for model in targets {
      if Task.isCancelled { return }
      do {
        _ = try await DepthEstimator.shared.estimateCached(
          cgImage: cgImage, model: model,
          cacheKey: DepthCacheKey(imageData: imageData, model: model))
      } catch {
        // モデル未変換などで1つ失敗しても、残りのモデルのプリフェッチは続行する。
      }
      // キャンセルで打ち切られた場合は推論が完了していないので、
      // 「完了した」印（インジケーターの消去）は付けない。
      if Task.isCancelled { return }
      finishInferring(model, for: imageData)
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
