import Foundation
import Markdown

/// Represents different layout modes for a slide page
public enum PageLayoutMode: Sendable {
  case headingOnly  // Only headings, centered
  case imageOnly  // Only images, full-screen
  case mixed  // Text and images, split layout (60/40)
  case urlOnly  // Heading(s) + single URL paragraph → large WebView
  case standard  // Standard vertical layout (current behavior)

  /// Detect layout mode from page elements
  public static func detect(from elements: [any Markup]) -> PageLayoutMode {
    let headings = elements.compactMap { $0 as? Heading }
    let images = elements.compactMap { $0 as? Markdown.Image }

    // Also check for images inside paragraphs
    let imagesInParagraphs =
      elements
      .compactMap { $0 as? Paragraph }
      .flatMap { paragraph in
        paragraph.children.compactMap { $0 as? Markdown.Image }
      }

    let allImages = images + imagesInParagraphs

    // Count non-heading, non-image content
    let hasOtherContent = elements.contains { element in
      if element is Heading { return false }
      if element is Markdown.Image { return false }
      if let paragraph = element as? Paragraph {
        // Check if paragraph has actual text content (excluding SoftBreak, LineBreak, etc.)
        return paragraph.children.contains { child in
          if child is Markdown.Image { return false }
          if child is SoftBreak { return false }
          if child is LineBreak { return false }
          return true
        }
      }
      return true  // Lists, code blocks, tables, etc.
    }

    // Check for URL-only layout: heading(s) + exactly one URL-only paragraph, nothing else
    let paragraphs = elements.compactMap { $0 as? Paragraph }
    let urlOnlyParagraphs = paragraphs.filter { $0.singleURL != nil }
    let nonHeadingElements = elements.filter { !($0 is Heading) }
    if urlOnlyParagraphs.count == 1 && nonHeadingElements.count == 1 && allImages.isEmpty {
      return .urlOnly
    }

    // Layout detection logic
    if !headings.isEmpty && allImages.isEmpty && !hasOtherContent {
      // Only headings present
      return .headingOnly
    } else if !allImages.isEmpty && headings.isEmpty && !hasOtherContent {
      // Only images present
      return .imageOnly
    } else if !allImages.isEmpty && (!headings.isEmpty || hasOtherContent) {
      // Mix of images and text/headings
      return .mixed
    } else {
      // Standard layout (text, code, lists, etc.)
      return .standard
    }
  }
}
