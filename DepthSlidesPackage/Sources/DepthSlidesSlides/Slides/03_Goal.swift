import MarkdownToSlide
import SlideKit
import SwiftUI

/// 冒頭でゴール（何を作りたいか）を先に見せるスライド。
/// 左が iPhone で撮った写真（Before）、右がミラーレスで撮った写真（目指す見た目）。
@Slide
struct GoalSlide: View {
  @Environment(\.slideTheme) var theme

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      Text("今日のゴール")
        .font(theme.headingH1Font)
        .foregroundStyle(theme.primaryTextColor)

      HStack(spacing: 40) {
        labeledPhoto(Image(.IMG_2569), label: "iPhone で撮った写真", sublabel: "背景までくっきり")
        Image(systemName: "arrow.right")
          .font(.system(size: 80, weight: .bold))
          .foregroundStyle(theme.accentColor)
        labeledPhoto(Image(.SDIM_4295_2), label: "ミラーレスで撮った写真", sublabel: "主題だけが浮き上がる")
      }
      .frame(maxHeight: .infinity)

      Text("iPhone の写真を、後処理でミラーレスのボケに近づける")
        .font(theme.headingH2Font)
        .foregroundStyle(theme.primaryTextColor)
        .frame(maxWidth: .infinity)
    }
    .padding(theme.contentPadding)
  }

  private func labeledPhoto(_ image: Image, label: String, sublabel: String) -> some View {
    VStack(spacing: 12) {
      image
        .resizable()
        .aspectRatio(contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
      Text(label)
        .font(theme.headingH3Font)
        .foregroundStyle(theme.primaryTextColor)
      Text(sublabel)
        .font(theme.bodyFont)
        .foregroundStyle(theme.secondaryTextColor)
    }
  }

  var script: String = """
    今日のゴールはこちらです。左がさっきの iPhone で撮った写真で、これを後処理で、右のミラーレスで撮ったような主題だけが浮き上がる写真に近づけたい、というのが今日のお話です。
    """

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview {
  SlidePreview {
    GoalSlide()
  }
}
