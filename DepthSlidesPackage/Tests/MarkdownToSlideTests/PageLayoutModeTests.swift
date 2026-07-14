import Foundation
import Markdown
import Testing

@testable import MarkdownToSlide

@Suite("PageLayoutMode.detect", .serialized)
struct PageLayoutModeTests {

  // MARK: - urlOnly

  @Test("Single explicit URL link is urlOnly")
  func singleExplicitURLLink() {
    let doc = Document(parsing: "[https://example.com](https://example.com)")
    let elements = Array(doc.children)
    #expect(PageLayoutMode.detect(from: elements) == .urlOnly)
  }

  @Test("Single autolink is urlOnly")
  func singleAutolink() {
    let doc = Document(parsing: "<https://example.com>")
    let elements = Array(doc.children)
    #expect(PageLayoutMode.detect(from: elements) == .urlOnly)
  }

  @Test("Heading + URL paragraph is urlOnly")
  func headingPlusURL() {
    let doc = Document(parsing: "# Title\n\n[https://example.com](https://example.com)")
    let elements = Array(doc.children)
    #expect(PageLayoutMode.detect(from: elements) == .urlOnly)
  }

  @Test("Multiple headings + URL paragraph is urlOnly")
  func multipleHeadingsPlusURL() {
    let doc = Document(
      parsing: "# Title\n## Subtitle\n\n[https://example.com](https://example.com)")
    let elements = Array(doc.children)
    #expect(PageLayoutMode.detect(from: elements) == .urlOnly)
  }

  // MARK: - headingOnly

  @Test("Single heading is headingOnly")
  func singleHeading() {
    let doc = Document(parsing: "# Title")
    let elements = Array(doc.children)
    #expect(PageLayoutMode.detect(from: elements) == .headingOnly)
  }

  @Test("Multiple headings only is headingOnly")
  func multipleHeadings() {
    let doc = Document(parsing: "# Title\n## Subtitle")
    let elements = Array(doc.children)
    #expect(PageLayoutMode.detect(from: elements) == .headingOnly)
  }

  // MARK: - standard

  @Test("URL paragraph with other text is standard")
  func urlWithOtherText() {
    let doc = Document(
      parsing: "# Title\n\nSome text.\n\n[https://example.com](https://example.com)")
    let elements = Array(doc.children)
    #expect(PageLayoutMode.detect(from: elements) == .standard)
  }

  @Test("Two text paragraphs is standard")
  func twoParagraphs() {
    let doc = Document(parsing: "First paragraph.\n\nSecond paragraph.")
    let elements = Array(doc.children)
    #expect(PageLayoutMode.detect(from: elements) == .standard)
  }

  @Test("Heading with regular text is standard")
  func headingWithText() {
    let doc = Document(parsing: "# Title\n\nSome content here.")
    let elements = Array(doc.children)
    #expect(PageLayoutMode.detect(from: elements) == .standard)
  }

  @Test("Heading with list is standard")
  func headingWithList() {
    let doc = Document(parsing: "# Title\n\n- item 1\n- item 2")
    let elements = Array(doc.children)
    #expect(PageLayoutMode.detect(from: elements) == .standard)
  }

  @Test("Heading + URL + list is standard (multiple non-heading elements)")
  func headingURLAndList() {
    let doc = Document(
      parsing: "# Title\n\n[https://example.com](https://example.com)\n\n- item 1")
    let elements = Array(doc.children)
    #expect(PageLayoutMode.detect(from: elements) == .standard)
  }

  // MARK: - mixed

  @Test("Text and image is mixed")
  func textAndImage() {
    let doc = Document(
      parsing: "# Title\n\nSome text.\n\n![alt](https://example.com/image.png)")
    let elements = Array(doc.children)
    #expect(PageLayoutMode.detect(from: elements) == .mixed)
  }

  // MARK: - imageOnly

  @Test("Single image only is imageOnly")
  func singleImageOnly() {
    let doc = Document(parsing: "![alt](https://example.com/image.png)")
    let elements = Array(doc.children)
    #expect(PageLayoutMode.detect(from: elements) == .imageOnly)
  }
}
