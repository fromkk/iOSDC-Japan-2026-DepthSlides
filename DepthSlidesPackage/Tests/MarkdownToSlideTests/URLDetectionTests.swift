import Foundation
import Markdown
import Testing

@testable import MarkdownToSlide

@Suite("Paragraph.singleURL", .serialized)
struct ParagraphURLDetectionTests {

  // MARK: - Returns URL

  @Test("Autolink <https://...> returns URL")
  func autolinkParagraph() throws {
    let doc = Document(parsing: "<https://example.com>")
    let para = try #require(Array(doc.children).first as? Paragraph)
    #expect(para.singleURL == URL(string: "https://example.com"))
  }

  @Test("Explicit Markdown link returns URL")
  func explicitLinkParagraph() throws {
    let doc = Document(parsing: "[https://example.com](https://example.com)")
    let para = try #require(Array(doc.children).first as? Paragraph)
    #expect(para.singleURL == URL(string: "https://example.com"))
  }

  @Test("Named link returns URL")
  func namedLinkParagraph() throws {
    let doc = Document(parsing: "[Visit Example](https://example.com)")
    let para = try #require(Array(doc.children).first as? Paragraph)
    #expect(para.singleURL == URL(string: "https://example.com"))
  }

  @Test("http:// link returns URL")
  func httpLinkParagraph() throws {
    let doc = Document(parsing: "[link](http://example.com)")
    let para = try #require(Array(doc.children).first as? Paragraph)
    #expect(para.singleURL == URL(string: "http://example.com"))
  }

  // MARK: - Returns nil

  @Test("Plain text returns nil")
  func plainTextParagraph() throws {
    let doc = Document(parsing: "Hello, world!")
    let para = try #require(Array(doc.children).first as? Paragraph)
    #expect(para.singleURL == nil)
  }

  @Test("Text with embedded link returns nil (multiple children)")
  func textWithEmbeddedLink() throws {
    let doc = Document(parsing: "See [example](https://example.com) for details")
    let para = try #require(Array(doc.children).first as? Paragraph)
    #expect(para.singleURL == nil)
  }

  @Test("Non-URL scheme (ftp) returns nil")
  func ftpSchemeParagraph() throws {
    let doc = Document(parsing: "[ftp link](ftp://example.com)")
    let para = try #require(Array(doc.children).first as? Paragraph)
    #expect(para.singleURL == nil)
  }
}

@Suite("ListItem.containedURL", .serialized)
struct ListItemURLDetectionTests {

  // MARK: - Returns URL

  @Test("List item with explicit link returns URL")
  func listItemWithExplicitLink() throws {
    let doc = Document(parsing: "- [https://example.com](https://example.com)")
    let list = try #require(Array(doc.children).first as? UnorderedList)
    let item = try #require(Array(list.listItems).first)
    #expect(item.containedURL == URL(string: "https://example.com"))
  }

  @Test("List item with named link returns URL")
  func listItemWithNamedLink() throws {
    let doc = Document(parsing: "- [Visit](https://example.com)")
    let list = try #require(Array(doc.children).first as? UnorderedList)
    let item = try #require(Array(list.listItems).first)
    #expect(item.containedURL == URL(string: "https://example.com"))
  }

  @Test("List item with autolink returns URL")
  func listItemWithAutolink() throws {
    let doc = Document(parsing: "- <https://example.com>")
    let list = try #require(Array(doc.children).first as? UnorderedList)
    let item = try #require(Array(list.listItems).first)
    #expect(item.containedURL == URL(string: "https://example.com"))
  }

  @Test("Only the item containing a URL has containedURL")
  func onlyURLItemMatches() throws {
    let markdown = """
      - something
      - [link](https://example.com)
      - more text
      """
    let doc = Document(parsing: markdown)
    let list = try #require(Array(doc.children).first as? UnorderedList)
    let items = Array(list.listItems)
    try #require(items.count == 3)
    #expect(items[0].containedURL == nil)
    #expect(items[1].containedURL == URL(string: "https://example.com"))
    #expect(items[2].containedURL == nil)
  }

  // MARK: - Returns nil

  @Test("Plain text list item returns nil")
  func plainTextListItem() throws {
    let doc = Document(parsing: "- just some text")
    let list = try #require(Array(doc.children).first as? UnorderedList)
    let item = try #require(Array(list.listItems).first)
    #expect(item.containedURL == nil)
  }

  @Test("All non-URL items return nil")
  func allNonURLItems() throws {
    let markdown = """
      - something
      - more text
      - last item
      """
    let doc = Document(parsing: markdown)
    let list = try #require(Array(doc.children).first as? UnorderedList)
    for item in list.listItems {
      #expect(item.containedURL == nil)
    }
  }
}
