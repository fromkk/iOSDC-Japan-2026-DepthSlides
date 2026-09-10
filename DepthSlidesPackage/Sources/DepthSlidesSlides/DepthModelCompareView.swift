import CoreImage
import ImageIO
import MarkdownToSlide
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 登壇中に実際の写真を選び、利用できる深度推定モデルすべての結果を一覧で
/// 見比べるスライド向けView。開発用の簡易デモ `DepthModelPickerView` とは別に、
/// 本番のスライドで使う機能（ファイル選択・iPhone からの受信・キャッシュ）を
/// まとめて持つ。
///
/// 後のボケ比較（`BokehFilterResultGridView`）と同じ形で、左上に元画像、続けて
/// モデルの結果をタイルで並べ、タイトルは画像の下に置く。3 列なので iPhone は
/// 元画像 + 4 モデルで 2 段、macOS は Depth Pro が加わって 3×2 が埋まる。
/// セグメントで「深度画像 / モデルの入手・変換コード / 推論コード」を切り替えても
/// タイルの位置は変えず、同じモデルが常に同じ場所に来るようにしている。
/// モデルを 1 つずつ切り替えて見比べる方式は、どのモデルを見ているのか聴衆が
/// 追いづらかったため、全部を同時に並べる方式に変えた。タイルをタップすると拡大
/// して、深度は元画像との見え隠れ比較、コードはスライドの Markdown 描画で
/// フルサイズに読める。
struct DepthModelCompareView: View {
  private enum DisplayMode: String, CaseIterable, Identifiable {
    case depth, conversionCode, code

    var id: String { rawValue }

    var displayName: String {
      switch self {
      case .depth: "深度画像"
      case .conversionCode: "モデルの入手・変換コード"
      case .code: "推論コード"
      }
    }
  }

  /// 各モデルの推論の進み具合。タイルのプレースホルダーに表示する。
  private enum CellStatus: Equatable {
    case waiting
    case working(String)
    case failed(String)
  }

  /// 格子の 1 マス。先頭が元画像で、以降は `DepthModel.availableCases` の順。
  private enum Tile: Hashable {
    case original
    case model(DepthModel)
  }

  @Environment(\.slideTheme) var slideTheme

  /// 表示時に自動で読み込む写真。プレビューで格子の見た目を確認するためのもので、
  /// 本番のスライドでは渡さない（登壇中に撮った写真を読み込む）。
  var initialImageData: Data?

  @State private var pickerItem: PhotosPickerItem?
  @State private var isFileImporterPresented = false
  @State private var isPeerCaptureCameraPresented = false
  @State private var isPeerReceiverPresented = false
  @State private var displayMode: DisplayMode = .depth

  @State private var imageData: Data?
  @State private var originalCGImage: CGImage?
  @State private var depthImages: [DepthModel: CGImage] = [:]
  @State private var statuses: [DepthModel: CellStatus] = [:]
  @State private var statusMessage = "写真を選んでください"

  /// タップして拡大表示中のセル。`nil` なら格子表示。
  @State private var expandedModel: DepthModel?
  @State private var zoomState = ImageZoomState.identity
  @State private var revealFraction: CGFloat = 0.5

  /// 現在の写真に対して全モデルの推論を直列に進めるタスク。次の写真が選ばれたら
  /// 古いものはキャンセルして置き換える。
  @State private var estimationTask: Task<Void, Never>?

  private let context = CIContext()
  private let converter = MarkdownToSlideConverter()

  /// 格子に並べるモデル。`DepthModel.availableCases` の並び（写真埋め込み →
  /// リリースの古い順）そのまま。
  private var models: [DepthModel] { DepthModel.availableCases }

  private var tiles: [Tile] { [.original] + models.map(Tile.model) }

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

      // 素のラベルだけだと当たり判定が文字の幅しかなく、スライド表示で縮小される
      // と押しにくかったため、横幅いっぱいの大きな枠付きボタンにしている。
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
    .task {
      if let initialImageData, imageData == nil {
        await loadImage(from: initialImageData)
      }
    }
    .onChange(of: displayMode) { _, _ in
      // 深度画像で拡大したままコードに切り替えると、そのモデルのコードだけが
      // 全面に出て他と見比べられないので、格子に戻す。
      expandedModel = nil
    }
    .onDisappear {
      // スライドから離れたら、順番待ちの推論（特に最重量の depthPro）を
      // 開始させない。すでに実行中の1件の `MLModel.prediction` は同期実行の
      // ため中断できず、それだけは完走する。
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

  // MARK: - 表示

  @ViewBuilder
  private var contentView: some View {
    if let expandedModel {
      expandedView(for: expandedModel)
        .padding(8)
    } else if displayMode == .depth && originalCGImage == nil {
      // 写真を選ぶ前はコードだけ先に見せられるようにし、深度画像モードでは
      // 案内文を出す（読み込み失敗のメッセージもここに出る）。
      statusText
    } else {
      grid
        .padding(8)
    }
  }

  /// 3 列固定。ボケ比較は 8 タイルで 4 列だが、こちらは 5〜6 タイルなので
  /// 3 列にしてタイルを大きく取る。
  private static let columnCount = 3

  private var grid: some View {
    let columns = Self.columnCount
    let rows = Int((Double(tiles.count) / Double(columns)).rounded(.up))
    return Grid(horizontalSpacing: 12, verticalSpacing: 12) {
      ForEach(0..<rows, id: \.self) { row in
        GridRow {
          ForEach(0..<columns, id: \.self) { column in
            let index = row * columns + column
            if index < tiles.count {
              tileView(tiles[index])
            } else {
              Color.clear
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private func tileView(_ tile: Tile) -> some View {
    switch tile {
    case .original:
      if let originalCGImage {
        imageTile(originalCGImage, title: "元画像")
      } else {
        // コードモードは写真を選ぶ前でも見られるので、元画像の枠だけ出しておく。
        placeholderTile(title: "元画像") {
          Text("写真を選んでください")
        }
      }
    case .model(let model):
      modelTile(for: model)
    }
  }

  @ViewBuilder
  private func modelTile(for model: DepthModel) -> some View {
    switch displayMode {
    case .depth:
      if let depth = depthImages[model] {
        imageTile(depth, title: model.displayName)
          .contentShape(Rectangle())
          .onTapGesture { expand(model) }
      } else {
        placeholderTile(title: model.displayName) {
          switch statuses[model] ?? .waiting {
          case .waiting:
            ProgressView()
            Text("順番待ち")
          case .working(let message):
            ProgressView()
            Text(message)
          case .failed(let message):
            Image(systemName: "exclamationmark.triangle")
            Text(message)
          }
        }
      }
    case .conversionCode:
      codeTile(document: CodeDocument(markdown: model.conversionMarkdown), model: model)
    case .code:
      codeTile(
        document: CodeDocument(title: model.codeSectionTitle, code: model.estimationCodeSample),
        model: model)
    }
  }

  /// タイルの共通の形。中身を枠いっぱいに広げ、タイトルを下に添える
  /// （`BokehFilterResultGridView.tileView` と同じ体裁）。
  private func tileFrame<Content: View>(
    title: String, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(spacing: 4) {
      content()
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      Text(title)
        .font(.system(size: 22))
        .foregroundStyle(slideTheme.primaryTextColor)
        .lineLimit(1)
    }
  }

  private func imageTile(_ image: CGImage, title: String) -> some View {
    tileFrame(title: title) {
      Image(decorative: image, scale: 1)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }

  private func placeholderTile<Content: View>(
    title: String, @ViewBuilder content: () -> Content
  ) -> some View {
    tileFrame(title: title) {
      VStack(spacing: 12) {
        content()
      }
      .font(.system(size: 22))
      .foregroundStyle(slideTheme.secondaryTextColor)
      .multilineTextAlignment(.center)
      .padding(24)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.04)))
    }
  }

  /// コードは格子の 1 マスに収まる大きさの等幅 Text で出し、読みたければタップで
  /// 拡大してもらう（Markdown 描画はスライド用の文字サイズで、マスには収まらない）。
  private func codeTile(document: CodeDocument, model: DepthModel) -> some View {
    tileFrame(title: model.displayName) {
      VStack(alignment: .leading, spacing: 8) {
        if let heading = document.title {
          Text(heading)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(slideTheme.primaryTextColor)
            .padding(.horizontal, 12)
            .padding(.top, 10)
        }
        ScrollView([.vertical, .horizontal]) {
          Text(document.body)
            .font(.system(size: 18, design: document.isCode ? .monospaced : .default))
            .foregroundStyle(slideTheme.primaryTextColor)
            .lineSpacing(3)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(RoundedRectangle(cornerRadius: 8).fill(slideTheme.tableBackgroundColor))
      .contentShape(Rectangle())
      .onTapGesture { expand(model) }
    }
  }

  @ViewBuilder
  private func expandedView(for model: DepthModel) -> some View {
    VStack(spacing: 8) {
      HStack {
        Text(model.displayName)
          .font(.system(size: 28, weight: .semibold))
          .foregroundStyle(slideTheme.primaryTextColor)
        Spacer()
        Button {
          expandedModel = nil
        } label: {
          Label("一覧に戻る", systemImage: "square.grid.2x2")
            .font(.system(size: 24))
        }
        .buttonStyle(.bordered)
      }

      switch displayMode {
      case .depth:
        if let originalCGImage, let depth = depthImages[model] {
          BeforeAfterImageCompareView(
            before: originalCGImage,
            after: depth,
            zoomState: $zoomState,
            revealFraction: $revealFraction
          )
        } else {
          statusText
        }
      case .conversionCode:
        ScrollView {
          converter.convertPage(model.conversionMarkdown)
        }
      case .code:
        ScrollView {
          converter.convertPage(
            """
            ### \(model.codeSectionTitle)

            ```swift
            \(model.estimationCodeSample)
            ```
            """)
        }
      }
    }
  }

  private func expand(_ model: DepthModel) {
    zoomState = .identity
    revealFraction = 0.5
    expandedModel = model
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

  /// Photos・ファイル・iPhone からの受信、どの経路も最終的にこの1箇所で同じ
  /// デコード処理に収束させる。
  private func loadImage(from data: Data) async {
    estimationTask?.cancel()
    estimationTask = nil

    depthImages = [:]
    statuses = [:]
    expandedModel = nil
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
    statuses = Dictionary(uniqueKeysWithValues: models.map { ($0, CellStatus.waiting) })

    estimationTask = Task { await estimateAllModels(imageData: data, cgImage: oriented) }
  }

  private func orientedCGImage(_ cgImage: CGImage, orientation: CGImagePropertyOrientation?)
    -> CGImage
  {
    guard let orientation else { return cgImage }
    let ciImage = CIImage(cgImage: cgImage).oriented(orientation)
    return context.createCGImage(ciImage, from: ciImage.extent) ?? cgImage
  }

  // MARK: - 推論

  /// 全モデルの推論を直列に進め、終わったものから格子に表示する。
  /// `DepthEstimator` は actor で推論本体が同期実行のため、1つの Task 内で
  /// 順番に await するだけで直列になる。depthPro（macOS のみ・最重量）は
  /// 他の結果を待たせないよう最後に回す。
  private func estimateAllModels(imageData: Data, cgImage: CGImage) async {
    var targets = models
    if let index = targets.firstIndex(of: .depthPro) {
      targets.append(targets.remove(at: index))
    }

    for model in targets {
      if Task.isCancelled { return }
      await estimate(model, imageData: imageData, cgImage: cgImage)
    }
  }

  private func estimate(_ model: DepthModel, imageData: Data, cgImage: CGImage) async {
    let cacheKey = DepthCacheKey(imageData: imageData, model: model)

    // キャッシュ済みなら actor（推論キュー）を経由せず即表示する。
    if let cached = DepthEstimator.shared.cachedDepthImage(for: cacheKey) {
      store(cached, for: model, imageData: imageData)
      return
    }

    if model == .embeddedDepth {
      setStatus(.working("写真に埋め込まれた深度情報を抽出中..."), for: model, imageData: imageData)
      do {
        let result = try await Task.detached(priority: .userInitiated) {
          try EmbeddedDepthExtractor.extractDepthImage(from: imageData)
        }.value
        DepthEstimator.shared.storeDepthImage(result, for: cacheKey)
        store(result, for: model, imageData: imageData)
      } catch EmbeddedDepthExtractor.ExtractionError.noEmbeddedDepthData {
        setStatus(
          .failed("この写真には深度情報が含まれていません（Portraitモードで撮影した写真をお試しください）"),
          for: model, imageData: imageData)
      } catch {
        setStatus(.failed("深度情報の抽出に失敗しました: \(error)"), for: model, imageData: imageData)
      }
      return
    }

    guard model.packageURL != nil else {
      setStatus(
        .failed("モデルが見つかりません。scripts/ 以下のスクリプトを実行してください"),
        for: model, imageData: imageData)
      return
    }

    setStatus(.working("推論を準備中..."), for: model, imageData: imageData)

    do {
      let result = try await DepthEstimator.shared.estimateCached(
        cgImage: cgImage, model: model, cacheKey: cacheKey
      ) { phase in
        let message =
          switch phase {
          case .compilingModel: "モデルをコンパイル中...（初回のみ）"
          case .loadingModel: "モデルを読み込み中...（この端末での初回は数分かかることがあります）"
          case .inferring: "推論中..."
          }
        setStatus(.working(message), for: model, imageData: imageData)
      }
      store(result, for: model, imageData: imageData)
    } catch is CancellationError {
      // 画面から離れた・写真を切り替えた等で不要になった推論。
      return
    } catch {
      setStatus(.failed("推論に失敗しました: \(error)"), for: model, imageData: imageData)
    }
  }

  /// await 中に別の写真へ切り替わっていた場合、古い写真の結果で新しい写真の
  /// 表示を上書きしない。
  private func store(_ image: CGImage, for model: DepthModel, imageData: Data) {
    guard imageData == self.imageData else { return }
    depthImages[model] = image
    statuses[model] = nil
  }

  private func setStatus(_ status: CellStatus, for model: DepthModel, imageData: Data) {
    guard imageData == self.imageData else { return }
    statuses[model] = status
  }
}

/// 格子のマスに出すために、`DepthModel` のコード用 Markdown を見出しと本文に
/// ほぐしたもの。Markdown をまともに描くのは拡大表示（`convertPage`）に任せ、
/// ここでは `###` の見出し行とコードフェンスを剥がすだけにとどめる。
private struct CodeDocument {
  let title: String?
  let body: String
  /// 本文がコードなら等幅で出す（写真埋め込みの入手方法のような散文は通常のフォント）。
  let isCode: Bool

  init(title: String, code: String) {
    self.title = title
    self.body = code
    self.isCode = true
  }

  init(markdown: String) {
    var title: String?
    var lines: [String] = []
    var sawFence = false
    for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
      if line.hasPrefix("### ") {
        title = String(line.dropFirst(4))
      } else if line.hasPrefix("```") {
        sawFence = true
      } else {
        lines.append(String(line))
      }
    }
    self.title = title
    self.body = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    self.isCode = sawFence
  }
}

#Preview("写真を選ぶ前") {
  DepthModelCompareView()
    .padding()
}

#Preview("サンプル写真") {
  DepthModelCompareView(initialImageData: DepthSampleAssets.data(for: .portraitWithDepth))
    .padding()
    .frame(width: 1920, height: 1080)
}
