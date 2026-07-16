import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct SaitamaSwiftPR: View {
  let converter = MarkdownToSlideConverter()

  var body: some View {
    SlideWrapper {
      converter.convertPage(
        """
        # PR 11/21(土) Saitama.swift やります

        - 埼玉県初のJapan-\\(region).swift
        - 所沢市民文化センター　ミューズが会場
        - ぎょうざの満洲で懇親会やります
          - 少し早い忘年会として
          - 人生トークなどもできる
          - 一緒に餃子食べましょう
        """
      )
    }
  }

  var script: String = """
    最後に宣伝です。11月21日土曜日に、埼玉県初の Japan-\\(region).swift、Saitama.swift をやります。
    会場は所沢市民文化センター ミューズです。
    懇親会はぎょうざの満洲でやります。少し早い忘年会として、人生トークなどもしつつ、一緒に餃子を食べましょう。
    以上です。ご清聴ありがとうございました。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    SaitamaSwiftPR()
  }
}
