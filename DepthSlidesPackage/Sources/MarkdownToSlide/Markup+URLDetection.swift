import Foundation
import Markdown

extension Paragraph {
  /// Returns the URL if this paragraph contains only a single URL (bare URL text or Link).
  var singleURL: URL? {
    let significant = children.filter { !($0 is SoftBreak) && !($0 is LineBreak) }
    guard significant.count == 1 else { return nil }
    return urlFrom(markup: significant[0])
  }
}

extension ListItem {
  /// Returns the first URL found in this list item's inline content.
  var containedURL: URL? {
    for child in children {
      guard let paragraph = child as? Paragraph else { continue }
      for inline in paragraph.children {
        if let url = urlFrom(markup: inline) {
          return url
        }
      }
    }
    return nil
  }
}

private func urlFrom(markup: any Markup) -> URL? {
  if let text = markup as? Markdown.Text {
    let trimmed = text.string.trimmingCharacters(in: .whitespacesAndNewlines)
    if let url = URL(string: trimmed),
      url.scheme == "https" || url.scheme == "http",
      url.host() != nil
    {
      return url
    }
  }

  return nil
}
