import SlideKit
import SwiftUI

/// スライドプレビュー用のビュー（縦スクロールで全スライドを表示）
public struct SlidePreviewView: View {
  @Environment(\.slideTheme) var theme

  public let markdown: String
  private let slides: [AnyView]

  public init(markdown: String) {
    self.markdown = markdown
    let markdownToSlide = MarkdownToSlideConverter()
    let slidesWithScripts = markdownToSlide(markdown)
    self.slides = slidesWithScripts.map { $0.0 }
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        ForEach(0..<slides.count, id: \.self) { index in
          slideContainer(for: index)
        }
      }
      .padding(.vertical, 24)
      .background(Color.gray.opacity(0.5))
    }
  }

  private func slideContainer(for index: Int) -> some View {
    VStack(spacing: 0) {
      ZStack {
        PresentationView(
          slideSize: SlideSize.standard16_9
        ) {
          slides[index]
            .background(theme.backgroundColor)
        }
        .slideTheme(theme)
      }
      .aspectRatio(16 / 9, contentMode: .fit)
      .padding(.horizontal, 24)

      Text("\(index + 1) / \(slides.count)")
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.top, 8)
    }
  }
}

#Preview {
  SlidePreviewView(
    markdown: #"""
      # Hello _world_ ~太字~

      - リスト
      - です

      ---

      ## Page2

      - 太字 **太字？**
      - 斜線 _斜線？_

      ---

      ## Page3

      1. 数値系リスト
      1. 動くの？

      """#
  )
  .environment(\.slideTheme, SlideTheme.default)
}
