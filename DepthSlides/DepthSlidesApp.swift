import DepthSlidesSlides
import MarkdownToSlide
import SlideKit
import SwiftUI

#if !canImport(UIKit)
  @main
#endif
struct DepthSlidesApp: App {
  private static let configuration = SlideConfiguration()
  private static let syncCoordinator = PresentationSyncCoordinator()
  let theme: MarkdownToSlide.SlideTheme = .default

  init() {
    #if os(macOS)
      // --export-pdf 指定時は起動後に自動で PDF を書き出して終了する
      Task { @MainActor in
        await Self.runAutomaticPDFExportIfRequested()
      }
      // --render-bokeh 指定時は Before/After 画像を書き出して終了する
      Task { @MainActor in
        await Self.runBokehBeforeAfterRenderIfRequested()
      }
      // --export-script 指定時は読み上げ用の原稿を書き出して終了する
      Task { @MainActor in
        await Self.runScriptExportIfRequested()
      }
    #endif
  }
  /// macOS Presenter ウィンドウに表示する原稿のフォントサイズ
  private static let presenterScriptFontSize: CGFloat = 20

  var presentationContentView: some View {
    SlideRouterView(
      slideIndexController: Self.configuration.slideIndexController
    )
    .task {
      Self.syncCoordinator.start(attachingTo: Self.configuration.slideIndexController)
      // モデル比較スライドを開く前に、未永続化のモデルのコンパイルを裏で
      // 済ませておく（永続化済みならすぐ抜ける）。
      await warmUpDepthModelCompilation()
    }
    .environment(\.presentationSyncCoordinator, Self.syncCoordinator)
  }

  var body: some Scene {
    WindowGroup {
      PresentationView(slideSize: Self.configuration.size) {
        ZStack {
          theme.backgroundColor
          presentationContentView
        }
      }
      .slideTheme(theme)
      .preferredColorScheme(.light)
    }
    #if os(macOS)
      .windowStyle(.hiddenTitleBar)
      .commands {
        PresenterCommands(
          slideIndexController: Self.configuration.slideIndexController,
          syncCoordinator: Self.syncCoordinator
        )
      }
    #endif
    #if os(macOS)
      WindowGroup("Presenter", id: "presenter") {
        macOSPresenterView(
          slideSize: Self.configuration.size,
          slideIndexController: Self.configuration.slideIndexController
        ) {
          SlideRouterView(slideIndexController: Self.configuration.slideIndexController)
            .background(theme.backgroundColor)
            // Presenter 用に大きくした font 環境がスライド本体に漏れないようリセット
            .font(nil)
        }
        // macOSPresenterView の原稿 Text はフォント未指定で環境の font を継承するので、
        // ここで上書きして Presenter の原稿を読みやすい大きさにする。
        .font(.system(size: Self.presenterScriptFontSize))
        .environment(\.presentationSyncCoordinator, Self.syncCoordinator)
        .environment(\.slideAudioEnabled, false)
        .preferredColorScheme(.light)
      }
    #endif
  }

  #if os(macOS)
    /// 起動引数 `--export-pdf <path>` が指定されていたら、保存パネルなしで
    /// 全スライドを PDF に書き出してアプリを終了する（CLI からの自動書き出し用）。
    private static func runAutomaticPDFExportIfRequested() async {
      let arguments = CommandLine.arguments
      guard let flagIndex = arguments.firstIndex(of: "--export-pdf") else { return }
      FileHandle.standardError.write(Data("[PDFExport] launch arguments: \(arguments)\n".utf8))
      // ウィンドウが出てから書き出しを始める（起動直後はまだシーンが無い）
      try? await Task.sleep(for: .seconds(1))
      let outputPath =
        arguments.indices.contains(flagIndex + 1)
        ? arguments[flagIndex + 1]
        : "DepthSlides.pdf"
      let url = URL(fileURLWithPath: outputPath)

      do {
        try await SlidePDFExporter().export(to: url, slideIndexController: configuration.slideIndexController)
        FileHandle.standardError.write(Data("Exported PDF to \(url.path)\n".utf8))
        exit(0)
      } catch {
        FileHandle.standardError.write(Data("PDF export failed: \(error)\n".utf8))
        exit(1)
      }
    }

    /// 起動引数 `--export-script <path>` が指定されていたら、全スライドの
    /// 原稿を読み上げ用テキストに書き出してアプリを終了する
    /// （scripts/export_speaker_notes.sh）。
    private static func runScriptExportIfRequested() async {
      let arguments = CommandLine.arguments
      guard let flagIndex = arguments.firstIndex(of: "--export-script") else { return }
      let outputPath =
        arguments.indices.contains(flagIndex + 1)
        ? arguments[flagIndex + 1]
        : "speakernote_tts.txt"
      let url = URL(fileURLWithPath: outputPath)

      do {
        try SlideScriptExporter.export(
          to: url, slideIndexController: configuration.slideIndexController)
        FileHandle.standardError.write(Data("[ScriptExport] wrote \(url.path)\n".utf8))
        exit(0)
      } catch {
        FileHandle.standardError.write(Data("[ScriptExport] failed: \(error)\n".utf8))
        exit(1)
      }
    }

    /// 起動引数 `--render-bokeh <入力ディレクトリ> <出力ディレクトリ>` が
    /// 指定されていたら、まとめ前の Before/After 比較スライド用の画像を
    /// 書き出してアプリを終了する（scripts/render_bokeh_before_after.sh）。
    private static func runBokehBeforeAfterRenderIfRequested() async {
      let arguments = CommandLine.arguments
      guard let flagIndex = arguments.firstIndex(of: "--render-bokeh") else { return }
      guard arguments.indices.contains(flagIndex + 2) else {
        FileHandle.standardError.write(
          Data("usage: --render-bokeh <inputDirectory> <outputDirectory>\n".utf8))
        exit(1)
      }
      let input = URL(fileURLWithPath: arguments[flagIndex + 1])
      let output = URL(fileURLWithPath: arguments[flagIndex + 2])
      do {
        try await BokehBeforeAfterRenderer.render(inputDirectory: input, outputDirectory: output)
        exit(0)
      } catch {
        FileHandle.standardError.write(Data("Bokeh render failed: \(error)\n".utf8))
        exit(1)
      }
    }
  #endif
}
