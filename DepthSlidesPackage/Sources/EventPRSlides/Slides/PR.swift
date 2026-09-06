import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
public struct PR: View {
  @Environment(\.slideTheme) var theme

  public init() {}

  public var body: some View {
    HStack(alignment: .center) {
      Text("PR")
        .font(theme.headingH1Font)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
  }
}

#Preview {
  SlidePreview {
    PR()
  }
}
