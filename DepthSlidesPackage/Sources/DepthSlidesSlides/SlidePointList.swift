import SwiftUI

/// 本文の 1 項目。見出し語と、その下に置く補足。
///
/// 箇条書き 1 行に長文を詰めるのをやめて「見出し語 + 補足」の 2 層にするための型。
/// 遠くからは見出し語だけ、近くまで読める人は補足まで読める、という読ませ方にする。
struct SlidePoint: Identifiable {
  let term: String
  let detail: String?

  var id: String { term }

  init(_ term: String, _ detail: String? = nil) {
    self.term = term
    self.detail = detail
  }
}

/// `SlidePoint` を並べる。`columns` が 2 のときは 2 列に折り返す。
///
/// 2 列にすると 1 列あたりの幅は 1920 - パディング 120 - 列間 88 の半分で 856pt。
/// 補足（36pt）はここで全角 23 文字ほどで折り返すので、2 行に割れると項目ごとの
/// 高さが揃わず読みにくくなる。補足は 1 行に収まる長さで書くこと。
struct SlidePointList: View {
  @Environment(\.slideTheme) private var theme

  let points: [SlidePoint]
  var columns: Int = 1

  private var gridColumns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(), spacing: 88, alignment: .topLeading),
      count: max(1, columns))
  }

  var body: some View {
    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 56) {
      ForEach(points) { point in
        VStack(alignment: .leading, spacing: 16) {
          Rectangle()
            .fill(theme.secondaryTextColor)
            .frame(width: 48, height: 3)

          Text(point.term)
            .font(theme.headingH4Font)
            .foregroundStyle(theme.primaryTextColor)
            .fixedSize(horizontal: false, vertical: true)

          if let detail = point.detail {
            Text(detail)
              .font(.system(size: 36))
              .foregroundStyle(theme.secondaryTextColor)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}

#Preview {
  SlidePointList(
    points: [
      SlidePoint("Core ML / Core AI 向けの変換が要る", "Core AI は Core ML の後継。Xcode 27 から"),
      SlidePoint("モデルのサイズが大きい", "同梱するぶんアプリのサイズも増える"),
      SlidePoint("Depth Pro は Mac 並みの性能が要る", "とくにメモリ"),
      SlidePoint("ライセンスがモデルごとに違う", "サイズによって商用可否が変わる"),
    ],
    columns: 2
  )
  .padding(60)
  .frame(width: 1920, height: 1080)
}
