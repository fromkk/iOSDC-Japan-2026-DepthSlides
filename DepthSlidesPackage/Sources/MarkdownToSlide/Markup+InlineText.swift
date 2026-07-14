import Markdown
import SwiftUI

extension Markup {
  @ViewBuilder
  var toView: some View {
    if let text = self as? Markdown.Text {
      SwiftUI.Text(text.string)
    }
  }

  var toInlineText: SwiftUI.Text {
    switch self {
    case let text as Markdown.Text:
      return SwiftUI.Text(text.string)
    case let strong as Strong:
      return strong.children
        .reduce(SwiftUI.Text("")) { SwiftUI.Text("\($0)\($1.toInlineText)") }
        .bold()
    case let emphasis as Emphasis:
      return emphasis.children
        .reduce(SwiftUI.Text("")) { SwiftUI.Text("\($0)\($1.toInlineText)") }
        .italic()
    case let inlineCode as InlineCode:
      return SwiftUI.Text(inlineCode.code)
        .fontDesign(.monospaced)
    case let strikethrough as Strikethrough:
      return strikethrough.children
        .reduce(SwiftUI.Text("")) { SwiftUI.Text("\($0)\($1.toInlineText)") }
        .strikethrough()
    case let link as Markdown.Link:
      // リンクテキストを子要素から抽出
      let linkText = extractPlainText(from: link.children)
      let destination = link.destination ?? ""
      // SwiftUIのTextはMarkdown記法をサポートしているので、そのまま渡す
      return SwiftUI.Text(.init("[\(linkText)](\(destination))"))
    case is LineBreak:
      return SwiftUI.Text("\n")
    case is SoftBreak:
      return SwiftUI.Text(" ")
    case _ as Markdown.Image:
      // Inline画像の場合は、paragraphViewで別途処理されるため空のテキストを返す
      return SwiftUI.Text("")
    default:
      return SwiftUI.Text("")
    }
  }

  // MARK: - Helper Methods

  func extractPlainText(from children: MarkupChildren) -> String {
    children.compactMap { child -> String? in
      switch child {
      case let text as Markdown.Text:
        return text.string
      case let strong as Strong:
        return extractPlainText(from: strong.children)
      case let emphasis as Emphasis:
        return extractPlainText(from: emphasis.children)
      case let inlineCode as InlineCode:
        return inlineCode.code
      case let strikethrough as Strikethrough:
        return extractPlainText(from: strikethrough.children)
      case let link as Markdown.Link:
        return extractPlainText(from: link.children)
      default:
        return nil
      }
    }.joined()
  }
}
