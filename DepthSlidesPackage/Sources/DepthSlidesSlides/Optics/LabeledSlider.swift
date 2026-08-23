import MarkdownToSlide
import SwiftUI

/// A slider with a leading label and a trailing formatted value, reused by
/// both optics simulation slides.
struct LabeledSlider: View {
  @Environment(\.slideTheme) var slideTheme

  let label: String
  @Binding var value: CGFloat
  let range: ClosedRange<CGFloat>
  var format: (CGFloat) -> String = { String(format: "%.0f", $0) }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(label)
          .font(.system(size: 32))
          .foregroundStyle(slideTheme.primaryTextColor)
        Spacer()
        Text(format(value))
          .font(.system(size: 32))
          .foregroundStyle(slideTheme.secondaryTextColor)
          .monospacedDigit()
      }
      Slider(value: $value, in: range)
    }
  }
}
