import Markdown
import SwiftUI
import WebKit

struct Page {
  var elements: [any Markup] = []
  var script: String = ""

  @MainActor
  var toView: some View {
    AnyView(elements.toView)
  }
}

extension Sequence where Element == any Markup {
  @MainActor
  @ViewBuilder
  var toView: some View {
    PageContentView(elements: Array(self))
  }
}

private struct PageContentView: View {
  @Environment(\.slideTheme) private var theme
  let elements: [any Markup]

  var body: some View {
    let layoutMode = PageLayoutMode.detect(from: elements)

    ZStack(alignment: .bottomTrailing) {
      switch layoutMode {
      case .headingOnly:
        HeadingOnlyLayout(elements: elements, theme: theme)
      case .imageOnly:
        ImageOnlyLayout(elements: elements, theme: theme)
      case .mixed:
        MixedContentLayout(elements: elements, theme: theme)
      case .urlOnly:
        URLOnlyLayout(elements: elements, theme: theme)
      case .standard:
        StandardLayout(elements: elements, theme: theme)
      }
    }
    .environment(\.layoutMode, layoutMode)
  }
}

// MARK: - Heading-Only Layout

private struct HeadingOnlyLayout: View {
  let elements: [any Markup]
  let theme: SlideTheme

  var body: some View {
    VStack(spacing: theme.blockSpacing) {
      Spacer()
      ForEach(Array(elements.enumerated()), id: \.offset) { _, element in
        AnyView(element.toBlockView)
      }
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(theme.contentPadding)
  }
}

// MARK: - Image-Only Layout

private struct ImageOnlyLayout: View {
  let elements: [any Markup]
  let theme: SlideTheme

  var body: some View {
    ZStack {
      // Background color
      theme.backgroundColor.ignoresSafeArea()

      VStack(alignment: .center, spacing: theme.blockSpacing) {
        Spacer()
        // Render images
        // Use full screen only for single image, otherwise use normal size
        let isSingleImage = imageElements.count == 1
        ForEach(Array(imageElements.enumerated()), id: \.offset) { _, image in
          ImageView(image: image, theme: theme, useFullScreen: isSingleImage)
            .frame(maxWidth: .infinity)
        }
        Spacer()
      }
      .frame(maxWidth: .infinity)
      .padding(theme.contentPadding)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var imageElements: [Markdown.Image] {
    var images: [Markdown.Image] = []

    for element in elements {
      if let image = element as? Markdown.Image {
        images.append(image)
      } else if let paragraph = element as? Paragraph {
        images.append(
          contentsOf: paragraph.children.compactMap { $0 as? Markdown.Image }
        )
      }
    }

    return images
  }
}

// MARK: - Mixed Content Layout

private struct MixedContentLayout: View {
  let elements: [any Markup]
  let theme: SlideTheme

  var body: some View {
    GeometryReader { geometry in
      HStack(alignment: .top, spacing: theme.blockSpacing * 2) {
        // Left side: Text content (60%)
        VStack(alignment: .leading, spacing: theme.blockSpacing) {
          ForEach(Array(textElements.enumerated()), id: \.offset) {
            _,
            element in
            AnyView(element.toBlockView)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(width: geometry.size.width * 0.6 - theme.contentPadding * 1.5)

        // Right side: Images (40%)
        VStack(alignment: .center, spacing: theme.blockSpacing) {
          Spacer()
          ForEach(Array(imageElements.enumerated()), id: \.offset) { _, image in
            ImageView(image: image, theme: theme)
          }
          Spacer()
        }
        .frame(width: geometry.size.width * 0.4 - theme.contentPadding * 0.5)
      }
      .padding(theme.contentPadding)
    }
  }

  private var textElements: [any Markup] {
    elements.filter { element in
      if element is Markdown.Image { return false }
      if let paragraph = element as? Paragraph {
        // Only include paragraphs that have text (not just images)
        return paragraph.children.contains { !($0 is Markdown.Image) }
      }
      return true
    }
  }

  private var imageElements: [Markdown.Image] {
    var images: [Markdown.Image] = []

    for element in elements {
      if let image = element as? Markdown.Image {
        images.append(image)
      } else if let paragraph = element as? Paragraph {
        images.append(
          contentsOf: paragraph.children.compactMap { $0 as? Markdown.Image }
        )
      }
    }

    return images
  }
}

// MARK: - URL-Only Layout

private struct URLOnlyLayout: View {
  let elements: [any Markup]
  let theme: SlideTheme

  var body: some View {
    VStack(alignment: .leading, spacing: theme.blockSpacing) {
      ForEach(Array(headings.enumerated()), id: \.offset) { _, heading in
        AnyView(heading.toBlockView)
      }

      if let url = urlParagraph?.singleURL {
        Text(url.absoluteString)
          .font(theme.bodyFont)
          .foregroundColor(theme.linkColor)

        WebView(url: url)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(theme.contentPadding)
  }

  private var headings: [any Markup] {
    elements.compactMap { $0 as? Heading }
  }

  private var urlParagraph: Paragraph? {
    elements.compactMap { $0 as? Paragraph }.first
  }
}

// MARK: - Standard Layout

private struct StandardLayout: View {
  let elements: [any Markup]
  let theme: SlideTheme

  var body: some View {
    VStack(alignment: .leading, spacing: theme.blockSpacing) {
      ForEach(Array(elements.enumerated()), id: \.offset) { _, element in
        AnyView(element.toBlockView)
      }
      Spacer()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(theme.contentPadding)
  }
}
