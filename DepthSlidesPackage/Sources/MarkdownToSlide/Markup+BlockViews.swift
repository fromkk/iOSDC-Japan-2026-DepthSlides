import Markdown
import SlideKit
import SwiftUI

extension Markup {
  @MainActor
  @ViewBuilder
  var toBlockView: some View {
    BlockViewContainer(markup: self)
  }
}

// MARK: - Block View Container

private struct BlockViewContainer: View {
  @Environment(\.slideTheme) private var theme
  @Environment(\.colorScheme) var colorScheme: ColorScheme
  let markup: any Markup

  var body: some View {
    switch markup {
    case let heading as Heading:
      HeadingView(heading: heading, theme: theme)
    case let paragraph as Paragraph:
      ParagraphView(paragraph: paragraph, theme: theme)
    case let unorderedList as UnorderedList:
      AnyView(markup.unorderedListView(unorderedList))
        .foregroundColor(theme.primaryTextColor)
        .tint(theme.linkColor)
    case let orderedList as OrderedList:
      AnyView(markup.orderedListView(orderedList))
        .foregroundColor(theme.primaryTextColor)
        .tint(theme.linkColor)
    case let codeBlock as CodeBlock:
      CodeBlockView(
        codeBlock: codeBlock,
        theme: theme,
        colorScheme: colorScheme
      )
    case let image as Markdown.Image:
      ImageView(image: image, theme: theme)
    case let blockQuote as BlockQuote:
      BlockQuoteView(blockQuote: blockQuote, theme: theme)
    case let table as Markdown.Table:
      TableView(table: table, theme: theme)
    case let htmlBlock as HTMLBlock:
      HTMLView(htmlContent: htmlBlock.rawHTML)
    default:
      EmptyView()
    }
  }
}

// MARK: - Heading

private struct HeadingView: View {
  let heading: Heading
  let theme: SlideTheme

  var body: some View {
    let text = heading.children
      .reduce(SwiftUI.Text("")) { SwiftUI.Text("\($0)\($1.toInlineText)") }

    text.font(theme.fontForHeadingLevel(heading.level))
      .foregroundColor(theme.primaryTextColor)
      .tint(theme.linkColor)
  }
}

// MARK: - Paragraph

private struct ParagraphView: View {
  @Environment(\.layoutMode) private var layoutMode
  let paragraph: Paragraph
  let theme: SlideTheme

  var body: some View {
    // URL-only paragraph in non-urlOnly layout: show link preview card
    if let url = paragraph.singleURL {
      VStack(alignment: .leading, spacing: 8) {
        Text(url.absoluteString)
          .font(theme.bodyFont)
          .foregroundColor(theme.linkColor)
        LinkPreviewView(url: url)
      }
    } else {
      imageOrTextContent
    }
  }

  @ViewBuilder
  private var imageOrTextContent: some View {
    let images = paragraph.children.compactMap { $0 as? Markdown.Image }
    let hasImages = !images.isEmpty

    // Check for actual text content (excluding SoftBreak, LineBreak, etc.)
    let hasText = paragraph.children.contains { child in
      if child is Markdown.Image { return false }
      if child is SoftBreak { return false }
      if child is LineBreak { return false }
      return true
    }

    // In mixed layout, images are displayed separately on the right side
    let shouldShowImages = layoutMode != .mixed

    if hasImages && !hasText && shouldShowImages {
      // 画像のみの段落
      ForEach(Array(images.enumerated()), id: \.offset) { _, image in
        ImageView(image: image, theme: theme)
      }
    } else if hasImages && hasText {
      // テキストと画像が混在
      paragraph.children
        .reduce(SwiftUI.Text("")) { SwiftUI.Text("\($0)\($1.toInlineText)") }
        .font(theme.bodyFont)
        .foregroundColor(theme.primaryTextColor)
        .tint(theme.linkColor)

      // Only show images if not in mixed layout
      if shouldShowImages {
        ForEach(Array(images.enumerated()), id: \.offset) { _, image in
          ImageView(image: image, theme: theme)
        }
      }
    } else {
      // テキストのみ
      paragraph.children
        .reduce(SwiftUI.Text("")) { SwiftUI.Text("\($0)\($1.toInlineText)") }
        .font(theme.bodyFont)
        .foregroundColor(theme.primaryTextColor)
        .tint(theme.linkColor)
    }
  }
}

// MARK: - CodeBlock

private struct CodeBlockView: View {
  let codeBlock: CodeBlock
  let theme: SlideTheme
  let colorScheme: ColorScheme

  var body: some View {
    Code(
      codeBlock.code,
      syntaxHighlighter: colorScheme == .dark
        ? .presentationDark : .presentation
    )
  }
}

// MARK: - Image

struct ImageView: View {
  let image: Markdown.Image
  let theme: SlideTheme
  let useFullScreen: Bool

  init(image: Markdown.Image, theme: SlideTheme, useFullScreen: Bool = false) {
    self.image = image
    self.theme = theme
    self.useFullScreen = useFullScreen
  }

  var body: some View {
    if let source = image.source {
      // ローカルファイルパスの場合は同期的に読み込む
      if source.hasPrefix("/") {
        #if canImport(UIKit)
          let nativeImage = UIImage(contentsOfFile: source).map { SwiftUI.Image(uiImage: $0) }
        #else
          let nativeImage = NSImage(contentsOfFile: source).map { SwiftUI.Image(nsImage: $0) }
        #endif
        if let nativeImage {
          nativeImage
            .resizable()
            .scaledToFit()
            .applyFrame(useFullScreen: useFullScreen)
        } else {
          SwiftUI.Text("Failed to load local image")
            .foregroundColor(theme.errorColor)
            .font(theme.errorFont)
        }
      } else if let url = URL(string: source) {
        // リモートURLの場合はAsyncImageを使用
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .scaledToFit()
              .applyFrame(useFullScreen: useFullScreen)
          case .failure:
            SwiftUI.Text("Failed to load image")
              .foregroundColor(theme.errorColor)
              .font(theme.errorFont)
          case .empty:
            ProgressView()
          @unknown default:
            EmptyView()
          }
        }
      } else {
        EmptyView()
      }
    } else {
      EmptyView()
    }
  }
}

// Helper extension for applying frames
extension View {
  @ViewBuilder
  fileprivate func applyFrame(useFullScreen: Bool) -> some View {
    if useFullScreen {
      self.frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      self.frame(maxHeight: 600)
    }
  }
}

// MARK: - BlockQuote

private struct BlockQuoteView: View {
  let blockQuote: BlockQuote
  let theme: SlideTheme

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      ForEach(Array(blockQuote.children.enumerated()), id: \.offset) {
        _,
        child in
        AnyView(child.toBlockView)
      }
    }
    .tint(theme.linkColor)
    .padding(.leading, theme.blockQuoteLeadingPadding)
    .overlay {
      HStack {
        Rectangle()
          .fill(theme.blockQuoteBorderColor)
          .frame(width: theme.blockQuoteBorderWidth)

        Spacer()
      }
    }
    .opacity(0.75)
  }
}

// MARK: - Table

private struct TableView: View {
  let table: Markdown.Table
  let theme: SlideTheme

  var body: some View {
    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
      // ヘッダー行（Headには直接Cellが含まれる）
      GridRow {
        ForEach(Array(table.head.children.enumerated()), id: \.offset) {
          _,
          child in
          tableCellContentView(child, isHeader: true)
        }
      }

      Divider()

      // ボディ行（BodyにはRowが含まれる）
      ForEach(Array(table.body.children.enumerated()), id: \.offset) {
        _,
        child in
        if let row = child as? Markdown.Table.Row {
          GridRow {
            ForEach(Array(row.children.enumerated()), id: \.offset) { _, cell in
              tableCellContentView(cell, isHeader: false)
            }
          }
        }
      }
    }
    .padding(16)
    .background(theme.tableBackgroundColor)
    .cornerRadius(8)
  }

  @ViewBuilder
  private func tableCellContentView(_ cell: any Markup, isHeader: Bool)
    -> some View
  {
    // セルの内容からテキストを抽出
    let cellText = cell.children
      .reduce(SwiftUI.Text("")) { Text("\($0)\($1.toInlineText)") }

    Group {
      if isHeader {
        cellText
          .font(theme.tableHeaderFont)
      } else {
        cellText
          .font(theme.tableBodyFont)
      }
    }
    .foregroundColor(theme.primaryTextColor)
    .tint(theme.linkColor)
    .frame(minWidth: 100, alignment: .leading)
    .padding(8)
  }
}

// MARK: - HTMLBlock

extension Markup {
  @MainActor
  func htmlBlockView(_ htmlBlock: HTMLBlock) -> some View {
    HTMLView(htmlContent: htmlBlock.rawHTML)
  }
}
