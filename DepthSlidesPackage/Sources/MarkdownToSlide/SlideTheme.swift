import SwiftUI

extension Color {
  public static var systemBackground: Color {
    #if os(macOS)
      Color(.windowBackgroundColor)
    #else
      Color(.systemBackground)
    #endif
  }
}

/// SlideFeatureのカスタマイズ可能なテーマ
public struct SlideTheme: @unchecked Sendable {
  // MARK: - Fonts

  public var headingH1Font: Font
  public var headingH2Font: Font
  public var headingH3Font: Font
  public var headingH4Font: Font
  public var headingH5Font: Font
  public var headingH6Font: Font
  public var bodyFont: Font
  public var tableHeaderFont: Font
  public var tableBodyFont: Font
  public var errorFont: Font

  public var htmlBodyFontSize: CGFloat

  // MARK: - Colors

  public var backgroundColor: Color
  public var primaryTextColor: Color
  public var secondaryTextColor: Color
  public var accentColor: Color
  public var linkColor: Color
  public var errorColor: Color
  public var blockQuoteBorderColor: Color
  public var tableBackgroundColor: Color
  public var tableStripeColor: Color

  // MARK: - Spacing

  public var blockSpacing: CGFloat
  public var contentPadding: CGFloat
  public var blockQuoteLeadingPadding: CGFloat
  public var blockQuoteBorderWidth: CGFloat

  // MARK: - Initializer

  public init(
    // Fonts
    headingH1Font: Font = .system(size: 96, weight: .bold),
    headingH2Font: Font = .system(size: 72, weight: .bold),
    headingH3Font: Font = .system(size: 56, weight: .semibold),
    headingH4Font: Font = .system(size: 48, weight: .semibold),
    headingH5Font: Font = .system(size: 40, weight: .medium),
    headingH6Font: Font = .system(size: 36, weight: .medium),
    bodyFont: Font = .system(size: 48),
    tableHeaderFont: Font = .system(size: 48, weight: .bold),
    tableBodyFont: Font = .system(size: 48),
    errorFont: Font = .system(size: 36),
    htmlBodyFontSize: CGFloat = 48,
    // Colors
    backgroundColor: Color = .systemBackground,
    primaryTextColor: Color = .primary,
    secondaryTextColor: Color = .secondary,
    accentColor: Color = .accentColor,
    linkColor: Color = .accentColor,
    errorColor: Color = .red,
    blockQuoteBorderColor: Color = .gray,
    tableBackgroundColor: Color = Color.gray.opacity(0.1),
    tableStripeColor: Color = Color.gray.opacity(0.05),
    // Spacing
    blockSpacing: CGFloat = 32,
    contentPadding: CGFloat = 60,
    blockQuoteLeadingPadding: CGFloat = 32,
    blockQuoteBorderWidth: CGFloat = 8
  ) {
    self.headingH1Font = headingH1Font
    self.headingH2Font = headingH2Font
    self.headingH3Font = headingH3Font
    self.headingH4Font = headingH4Font
    self.headingH5Font = headingH5Font
    self.headingH6Font = headingH6Font
    self.bodyFont = bodyFont
    self.tableHeaderFont = tableHeaderFont
    self.tableBodyFont = tableBodyFont
    self.errorFont = errorFont
    self.htmlBodyFontSize = htmlBodyFontSize
    self.backgroundColor = backgroundColor
    self.primaryTextColor = primaryTextColor
    self.secondaryTextColor = secondaryTextColor
    self.accentColor = accentColor
    self.linkColor = linkColor
    self.errorColor = errorColor
    self.blockQuoteBorderColor = blockQuoteBorderColor
    self.tableBackgroundColor = tableBackgroundColor
    self.tableStripeColor = tableStripeColor

    self.blockSpacing = blockSpacing
    self.contentPadding = contentPadding
    self.blockQuoteLeadingPadding = blockQuoteLeadingPadding
    self.blockQuoteBorderWidth = blockQuoteBorderWidth
  }

  public static let `default` = SlideTheme()

  // MARK: - Helper Methods

  /// 見出しレベルに応じたフォントを返す
  public func fontForHeadingLevel(_ level: Int) -> Font {
    switch level {
    case 1: return headingH1Font
    case 2: return headingH2Font
    case 3: return headingH3Font
    case 4: return headingH4Font
    case 5: return headingH5Font
    case 6: return headingH6Font
    default: return bodyFont
    }
  }

  /// HTMLコンテンツ用のCSSスタイル文字列を生成
  public func generateHTMLCSS() -> String {
    // SwiftUIのColorからプラットフォームカラーに変換してRGB値を取得
    func colorToCSS(_ color: Color) -> String {
      #if canImport(UIKit)
        let nativeColor = UIColor(color)
      #else
        let nativeColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor.white
      #endif
      var red: CGFloat = 0
      var green: CGFloat = 0
      var blue: CGFloat = 0
      var alpha: CGFloat = 0
      nativeColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
      return "rgba(\(Int(red * 255)), \(Int(green * 255)), \(Int(blue * 255)), \(alpha))"
    }

    let bodyColorCSS = colorToCSS(primaryTextColor)

    return """
      body {
          margin: 0;
          padding: 16px;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          font-size: \(Int(htmlBodyFontSize))px;
          line-height: 1.6;
          color: \(bodyColorCSS);
      }
      """
  }
}

// MARK: - Environment Key

private struct SlideThemeKey: EnvironmentKey {
  static let defaultValue = SlideTheme.default
}

extension EnvironmentValues {
  public var slideTheme: SlideTheme {
    get { self[SlideThemeKey.self] }
    set { self[SlideThemeKey.self] = newValue }
  }
}

// MARK: - View Extension

extension View {
  /// SlideThemeを設定する
  public func slideTheme(_ theme: SlideTheme) -> some View {
    environment(\.slideTheme, theme)
  }
}
