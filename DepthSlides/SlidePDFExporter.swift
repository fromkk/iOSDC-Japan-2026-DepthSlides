import DepthSlidesSlides
import MarkdownToSlide
import PDFKit
import SlideKit
import SwiftUI

@MainActor
struct SlidePDFExporter {
  let slideSize = SlideSize.standard16_9
  /// Web ページの読み込みや、まとめスライドの深度推定（初回はモデルのコンパイルを含む）を待つ上限
  private static let webPageLoadTimeout: Duration = .seconds(120)
}

// MARK: - Slide のフェーズ操作ヘルパー（PhasedStateStoreProtocol を使わない）

extension Slide {
  /// SlidePhasedState の全フェーズ数を返す
  fileprivate var allPhaseCount: Int {
    SlidePhasedState.allCases.count
  }

  /// 指定インデックスのフェーズを container 上の PhasedStateStore に設定する
  fileprivate func setPhase(at index: Int, on container: ObservableObjectContainer) {
    let store: PhasedStateStore<SlidePhasedState> = container.resolve {
      PhasedStateStore()
    }
    guard let phase = SlidePhasedState(rawValue: index) else { return }
    store.current = phase
  }
}

// MARK: - 共通ヘルパー

extension SlidePDFExporter {
  fileprivate func slideView(
    for slide: any Slide,
    phaseIndex: Int,
    container: ObservableObjectContainer,
    tracker: WebPageLoadingTracker
  ) -> some View {
    // フェーズを設定
    slide.setPhase(at: phaseIndex, on: container)

    // PhaseWrapper は slideIndexController.phaseStateStore() 経由で
    // container から PhasedStateStore を取得するため、
    // PDF 用の container を持つ専用の SlideIndexController を作る
    let pdfController = SlideIndexController(
      container: container,
      slides: [slide]
    )

    // アプリ本体（DepthSlidesApp）と同じくテーマ背景を敷き、テーマを適用する。
    // これがないとダークテーマの白文字が透明背景に描かれ、PDF ではほぼ真っ白に見える。
    let theme = MarkdownToSlide.SlideTheme.default
    return SlideScreen(slideSize: slideSize) {
      ZStack {
        theme.backgroundColor
        AnyView(slide)
      }
    }
    .slideTheme(theme)
    .environment(\.slideIndexController, pdfController)
    .environment(\.observableObjectContainer, container)
    .environment(\.webPageLoadingTracker, tracker)
  }
}

// MARK: - iOS

#if canImport(UIKit)
  import UIKit

  extension SlidePDFExporter {
    func export(slideIndexController: SlideIndexController) async -> URL? {
      guard let pdfData = await createPDFData(slideIndexController: slideIndexController) else {
        return nil
      }

      let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("DepthSlides_\(Int(Date().timeIntervalSince1970)).pdf")
      do {
        try pdfData.write(to: tempURL)
        return tempURL
      } catch {
        return nil
      }
    }

    private func createPDFData(slideIndexController: SlideIndexController) async -> Data? {
      let pdfData = NSMutableData()
      let pageRect = CGRect(origin: .zero, size: slideSize)

      let keyWindow = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }

      var images: [UIImage] = []

      for slide in slideIndexController.slides {
        let container = ObservableObjectContainer()
        let phases = slide.allPhaseCount

        for phaseIndex in 0..<phases {
          let tracker = WebPageLoadingTracker()

          let view = slideView(
            for: slide,
            phaseIndex: phaseIndex,
            container: container,
            tracker: tracker
          )

          let hostingController = UIHostingController(rootView: view)
          hostingController.view.frame = pageRect.offsetBy(dx: 10000, dy: 10000)
          hostingController.view.bounds = pageRect
          hostingController.view.backgroundColor = .clear

          keyWindow?.addSubview(hostingController.view)
          hostingController.view.setNeedsLayout()
          hostingController.view.layoutIfNeeded()

          try? await Task.sleep(for: .milliseconds(300))
          await waitForTracker(tracker)

          let format = UIGraphicsImageRendererFormat()
          format.scale = 2.0
          format.opaque = false
          let renderer = UIGraphicsImageRenderer(size: slideSize, format: format)
          let image = renderer.image { _ in
            hostingController.view.layer.render(in: UIGraphicsGetCurrentContext()!)
          }
          images.append(image)

          hostingController.view.removeFromSuperview()
        }
      }

      UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
      for image in images {
        UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
        image.draw(in: pageRect)
      }
      UIGraphicsEndPDFContext()

      return pdfData.length > 0 ? pdfData as Data : nil
    }

    private func waitForTracker(_ tracker: WebPageLoadingTracker) async {
      let deadline = ContinuousClock.now + Self.webPageLoadTimeout
      while !tracker.isAllLoaded {
        guard ContinuousClock.now < deadline else { break }
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }
#endif

// MARK: - macOS

#if os(macOS)
  import AppKit
  import UniformTypeIdentifiers

  extension SlidePDFExporter {
    func exportWithSavePanel(slideIndexController: SlideIndexController) async {
      let panel = NSSavePanel()
      panel.allowedContentTypes = [.pdf]
      panel.nameFieldStringValue = "DepthSlides_\(Int(Date().timeIntervalSince1970)).pdf"

      let response = await panel.begin()
      guard response == .OK, let url = panel.url else { return }

      try? await export(to: url, slideIndexController: slideIndexController)
    }

    enum ExportError: Error {
      case renderFailed
    }

    /// 保存パネルを出さずに指定 URL へ PDF を書き出す。
    /// 起動引数 `--export-pdf <path>` からの自動書き出し（scripts/export_slides_pdf.sh）でも使う。
    func export(to url: URL, slideIndexController: SlideIndexController) async throws {
      guard let pdfData = await createPDFDataMac(slideIndexController: slideIndexController) else {
        throw ExportError.renderFailed
      }
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try pdfData.write(to: url)
    }

    private func createPDFDataMac(slideIndexController: SlideIndexController) async -> Data? {
      let pageRect = CGRect(origin: .zero, size: slideSize)

      let window = NSWindow(
        contentRect: NSRect(origin: CGPoint(x: -20000, y: -20000), size: slideSize),
        styleMask: .borderless,
        backing: .buffered,
        defer: false
      )

      var images: [NSImage] = []
      let totalSlides = slideIndexController.slides.count

      for (slideIndex, slide) in slideIndexController.slides.enumerated() {
        let container = ObservableObjectContainer()
        let phases = slide.allPhaseCount
        Self.log("slide \(slideIndex + 1)/\(totalSlides) \(type(of: slide)) phases=\(phases)")

        for phaseIndex in 0..<phases {
          let tracker = WebPageLoadingTracker()

          let view = slideView(
            for: slide,
            phaseIndex: phaseIndex,
            container: container,
            tracker: tracker
          )

          let hostingView = NSHostingView(rootView: view)
          hostingView.frame = pageRect
          window.contentView = hostingView
          window.orderBack(nil)

          try? await Task.sleep(for: .milliseconds(300))
          let waitStart = ContinuousClock.now
          await waitForTrackerMac(tracker)
          Self.log(
            "  phase \(phaseIndex + 1)/\(phases) waited \(ContinuousClock.now - waitStart) loaded=\(tracker.isAllLoaded)"
          )

          guard
            let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: pageRect)
          else { continue }
          hostingView.cacheDisplay(in: pageRect, to: bitmapRep)

          let image = NSImage(size: slideSize)
          image.addRepresentation(bitmapRep)
          images.append(image)
        }
      }

      window.orderOut(nil)

      let pdfDocument = PDFDocument()
      for (index, image) in images.enumerated() {
        if let page = PDFPage(image: image) {
          pdfDocument.insert(page, at: index)
        }
      }

      return pdfDocument.dataRepresentation()
    }

    private static func log(_ message: String) {
      FileHandle.standardError.write(Data("[PDFExport] \(message)\n".utf8))
    }

    private func waitForTrackerMac(_ tracker: WebPageLoadingTracker) async {
      let deadline = ContinuousClock.now + Self.webPageLoadTimeout
      while !tracker.isAllLoaded {
        guard ContinuousClock.now < deadline else { break }
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }
#endif
