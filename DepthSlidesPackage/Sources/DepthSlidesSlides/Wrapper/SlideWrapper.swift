import MarkdownToSlide
import SlideKit
import SwiftUI

struct SlideWrapper<Content: View>: View {
  @Environment(\.slideTheme) var slideTheme
  @ViewBuilder var content: () -> Content

  init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }

  var body: some View {
    ScrollView {
      content()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(slideTheme.backgroundColor)
  }
}
