import MarkdownToSlide
import SwiftUI

/// センサーサイズを実寸比の矩形で重ねて描く図。
/// Wikipedia の図は文字が小さく読めないため、SwiftUI で描き直して
/// iPhone のセンサーだけをアクセントカラーで強調する。
struct SensorSizeDiagramView: View {
  struct Sensor: Identifiable {
    let name: String
    let width: CGFloat  // mm
    let height: CGFloat  // mm
    var isHighlighted = false

    var id: String { name }
    var area: CGFloat { width * height }
  }

  /// 大きい順（後ろから前に重ねて描くため）
  static let sensors: [Sensor] = [
    Sensor(name: "中判 (44×33)", width: 44, height: 33),
    Sensor(name: "フルサイズ (36×24)", width: 36, height: 24),
    Sensor(name: "APS-C (23.5×15.6)", width: 23.5, height: 15.6),
    Sensor(name: "マイクロフォーサーズ (17.3×13)", width: 17.3, height: 13),
    Sensor(name: "1型 (13.2×8.8)", width: 13.2, height: 8.8),
    Sensor(name: "iPhone 17 Pro 1/1.28型 (9.8×7.3)", width: 9.8, height: 7.3, isHighlighted: true),
  ]

  @Environment(\.slideTheme) private var theme

  var body: some View {
    GeometryReader { geometry in
      let largest = Self.sensors[0]
      let scale = min(
        geometry.size.width / largest.width,
        geometry.size.height / largest.height)

      ZStack(alignment: .bottomLeading) {
        ForEach(Self.sensors) { sensor in
          let w = sensor.width * scale
          let h = sensor.height * scale
          ZStack(alignment: .topTrailing) {
            Rectangle()
              .fill(
                sensor.isHighlighted
                  ? theme.accentColor.opacity(0.8)
                  : theme.primaryTextColor.opacity(0.06))
            Rectangle()
              .stroke(
                sensor.isHighlighted ? theme.accentColor : theme.secondaryTextColor,
                lineWidth: sensor.isHighlighted ? 5 : 2)
            Text(sensor.name)
              .font(.system(size: sensor.isHighlighted ? 26 : 22, weight: sensor.isHighlighted ? .bold : .regular))
              .foregroundStyle(theme.primaryTextColor)
              .padding(8)
          }
          .frame(width: w, height: h)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottomLeading)
    }
  }

  /// フルサイズと iPhone の面積比（スライド本文で使う）
  static var fullFrameToiPhoneAreaRatio: Int {
    let full = sensors.first { $0.name.hasPrefix("フルサイズ") }!.area
    let phone = sensors.first { $0.isHighlighted }!.area
    return Int((full / phone).rounded())
  }
}

#Preview {
  SensorSizeDiagramView()
    .frame(width: 900, height: 700)
    .padding(40)
    .background(Color.black)
}
