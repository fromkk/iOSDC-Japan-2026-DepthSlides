import Markdown
import RegexBuilder
import SwiftUI

#if canImport(Playgrounds)
  import Playgrounds
#endif

@MainActor
public struct MarkdownToSlideConverter {
  public init() {}

  public func callAsFunction(_ markdown: String) -> [(AnyView, String)] {
    let (processedMarkdown, scripts) = extractScripts(from: markdown)
    let doc = Document(parsing: processedMarkdown)
    let views = parse(doc, scripts: scripts)
    return views
  }

  public func convertPage(_ markdown: String) -> AnyView {
    let doc = Document(parsing: markdown)
    return AnyView(doc.children.toView)
  }

  /// 画像プリロード付きの非同期パース（PDF生成など、確実に画像が必要な場合に使用）
  public func withImagePreload(_ markdown: String) async -> [(AnyView, String)] {
    let (processedMarkdown, scripts) = extractScripts(from: markdown)

    // 画像URLを事前にキャッシュ
    let markdownWithCachedImages = await preloadImages(from: processedMarkdown)

    let doc = Document(parsing: markdownWithCachedImages)
    let views = parse(doc, scripts: scripts)
    return views
  }

  /// Markdown内の画像URLを抽出して事前にキャッシュし、ローカルURLに置き換える
  private func preloadImages(from markdown: String) async -> String {
    // 画像URL抽出用の正規表現: ![alt](url)
    let imageRegex = /!\[([^\]]*)\]\(([^)]+)\)/

    // URLを抽出
    let imageURLs = markdown.matches(of: imageRegex).compactMap {
      match -> String? in
      String(match.output.2)
    }

    // 重複を除去
    let uniqueURLs = Array(Set(imageURLs))

    // URLが空の場合はそのまま返す
    guard !uniqueURLs.isEmpty else {
      return markdown
    }

    // 画像を一括キャッシュ
    let urlMapping = await ImageCacheManager.shared.cacheImages(uniqueURLs)

    // Markdown内のURLをローカルパスに置き換え
    var updatedMarkdown = markdown
    for (originalURL, localURL) in urlMapping {
      let localPath = localURL.path
      updatedMarkdown = updatedMarkdown.replacingOccurrences(
        of: "(\(originalURL))",
        with: "(\(localPath))"
      )
    }

    return updatedMarkdown
  }

  /// マークダウンから `^ ` で始まる行（トークスクリプト）を抽出
  private func extractScripts(from markdown: String) -> (
    markdown: String, scripts: [String]
  ) {
    let lines = markdown.components(separatedBy: .newlines)
    var processedLines: [String] = []
    var currentPageScript: [String] = []
    var allScripts: [String] = []

    for line in lines {
      if line.hasPrefix("^ ") {
        // トークスクリプト行
        let scriptLine = String(line.dropFirst(2))  // "^ " を削除
        currentPageScript.append(scriptLine)
      } else if line.hasPrefix("---") {
        // ページ区切り
        processedLines.append(line)
        // 現在のページのスクリプトを保存
        allScripts.append(currentPageScript.joined(separator: "\n"))
        currentPageScript = []
      } else {
        // 通常の行
        processedLines.append(line)
      }
    }

    // 最後のページのスクリプトを保存
    allScripts.append(currentPageScript.joined(separator: "\n"))

    return (processedLines.joined(separator: "\n"), allScripts)
  }

  func parse(_ markup: any Markup, scripts: [String]) -> [(AnyView, String)] {
    var pages: [Page] = []
    var currentPage: Page = .init()
    var scriptIndex = 0

    for child in markup.children {
      if child is ThematicBreak {
        // --- でページを分割
        if !currentPage.elements.isEmpty || scriptIndex < scripts.count {
          if scriptIndex < scripts.count {
            currentPage.script = scripts[scriptIndex]
            scriptIndex += 1
          }
          pages.append(currentPage)
          currentPage = .init()
        }
      } else {
        currentPage.elements.append(child)
      }
    }

    // 最後のページを追加
    if !currentPage.elements.isEmpty || scriptIndex < scripts.count {
      if scriptIndex < scripts.count {
        currentPage.script = scripts[scriptIndex]
      }
      pages.append(currentPage)
    }

    return pages.map { (AnyView($0.toView), $0.script) }
  }
}

#if canImport(Playgrounds)
  #Playground {
    let converter = MarkdownToSlideConverter()
    let views = converter("![image](https://placehold.jp/1280x780.png)")
  }
#endif
