import MarkdownToSlide
import SlideKit
import SwiftUI

/// 本のコラム（囲み記事）のような見せ方をするスライド。前後のスライドが
/// 見出し＋箇条書きの共通レイアウトなので、ここだけインセット罫で囲って
/// 別枠であることを示す。色は他のスライドと揃えてモノクロのみ。
@Slide
struct IPhonePhotoTips: View {
  @Environment(\.slideTheme) var slideTheme

  private struct Tip: Identifiable {
    let id: String
    let title: String
    let note: String?

    init(_ id: String, _ title: String, note: String? = nil) {
      self.id = id
      self.title = title
      self.note = note
    }
  }

  private let tips: [Tip] = [
    Tip("01", "被写体に近づく", note: "最短撮影距離まで寄る"),
    Tip("02", "被写体と背景を離す"),
    Tip("03", "望遠側（2x / 5x）で撮る", note: "焦点距離が長いほど被写界深度は浅くなる"),
  ]

  var body: some View {
    HStack(spacing: 72) {
      VStack(alignment: .leading, spacing: 0) {
        columnLabel

        // 自動折り返しだと「ぼか／す方法」で割れるので改行位置を指定する
        Text("スマホでも\n背景をぼかす方法")
          .font(.system(size: 80, weight: .bold))
          .lineSpacing(8)
          .foregroundStyle(slideTheme.primaryTextColor)
          .padding(.top, 44)
          .padding(.bottom, 56)

        VStack(alignment: .leading, spacing: 36) {
          ForEach(tips) { tip in
            tipRow(tip)
          }
        }
      }
      .frame(width: 940, alignment: .leading)

      samplePhoto
    }
    .padding(.horizontal, 88)
    .padding(.vertical, 72)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay {
      Rectangle()
        .strokeBorder(slideTheme.primaryTextColor.opacity(0.32), lineWidth: 2)
    }
    .padding(44)
    .background(slideTheme.backgroundColor)
  }

  private var columnLabel: some View {
    HStack(spacing: 28) {
      Rectangle()
        .fill(slideTheme.primaryTextColor)
        .frame(width: 64, height: 3)

      Text("COLUMN")
        .font(.system(size: 30, weight: .bold))
        .tracking(9)
        .foregroundStyle(slideTheme.primaryTextColor)
    }
  }

  private func tipRow(_ tip: Tip) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 36) {
      Text(tip.id)
        .font(.system(size: 46, weight: .bold))
        .monospacedDigit()
        .foregroundStyle(slideTheme.secondaryTextColor.opacity(0.7))
        .frame(width: 88, alignment: .leading)

      VStack(alignment: .leading, spacing: 12) {
        Text(tip.title)
          .font(.system(size: 48, weight: .semibold))
          .foregroundStyle(slideTheme.primaryTextColor)

        if let note = tip.note {
          Text(note)
            .font(.system(size: 34))
            .foregroundStyle(slideTheme.secondaryTextColor)
        }
      }
    }
  }

  /// 作例。同じ場所から 1x → 2x → 4x → 8x とレンズを切り替えた実写を自動で
  /// 広角→望遠の一方向で繰り返し再生し、望遠側ほど背景のビルがボケることを見せる（Tip 03 の裏付け）。
  private var samplePhoto: some View {
    TelephotoSequenceView()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  var script: String = """
    とはいえ撮り方の工夫でボケを稼ぐこともできます。
    被写界深度は被写体までの距離が近いほど浅くなるので、まずは被写体に思い切り近づくこと。
    そして被写体と背景を離すこと。背景が遠いほどボケは大きくなります。
    あとは望遠側で撮ること。焦点距離が長いほど被写界深度は浅くなるので、2倍や5倍のレンズを使うと有利です。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    IPhonePhotoTips()
  }
}
