import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct CameraObscuraOrigin: View {
  enum SlidePhase: Int, PhasedState {
    case initial
    case second
  }

  @Phase var phase: SlidePhase
  @Environment(\.slideTheme) var theme

  private var title: String {
    switch phase {
    case .initial: "カメラの元祖"
    case .second: "Camera Obscura"
    }
  }

  private var image: ImageResource {
    switch phase {
    case .initial: .cameraObscura
    case .second: .cameraObscura2
    }
  }

  private var source: String {
    switch phase {
    case .initial:
      "https://commons.wikimedia.org/wiki/File:1646_Athanasius_Kircher_-_Camera_obscura.jpg"
    case .second:
      "https://commons.wikimedia.org/wiki/File:Camera_Obscura_box18thCentury.jpg"
    }
  }

  var body: some View {
    // 以前は SlideKit の `HeaderSlide` にフルブリードの `.background` で画像を
    // 重ねていたが、タイトルが画像の下に隠れて読めなくなっていた。画像は背景では
    // なく本文として置き、他のスライドと同じヘッダーを載せている。
    VStack(alignment: .leading, spacing: 24) {
      SlideHeader(.cameraObscuraOrigin)

      Text(title)
        .font(theme.headingH2Font)
        .foregroundStyle(theme.primaryTextColor)

      Image(image)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      // 生 URL は長いので、リンク色ではなく本文の副次色で小さく置く。
      Text(verbatim: "出典: \(source)")
        .font(.system(size: 26))
        .foregroundStyle(theme.secondaryTextColor)
    }
    .padding(theme.contentPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  var script: String {
    switch phase {
    case .initial:
      return """
        そもそもカメラってどうなっているのでしょうか？仕組みを原点から振り返ってみようと思います。
        カメラの原点は、紀元前400年ごろにさかのぼります。
        戦国時代の思想家・墨子（ぼくし）の著作『墨経（ぼっけい）』に、暗い箱に小さな穴をあけると外の光が入り、逆さになって投影されることが記録されているらしいです。
        墨子（ぼくし）は光がまっすぐ進むから像が逆さまになる、という理由まで正しく理解していたそうです。
        これを小さな暗い部屋という意味でカメラ・オブスキュラと呼ばれています。
        """
    case .second:
      return """
        この仕組みを使って15世紀ごろ、レオナルド・ダ・ヴィンチが写生に利用したとされています。
        当初はフィルムのような記録用途ではなく、トレーシングペーパーのような半透明な紙に投影させて、それをなぞって絵を描くために利用していました。
        """
    }
  }

  var transition: AnyTransition = AnyTransition.awesome
}

#Preview(".initial") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<CameraObscuraOrigin.SlidePhase>(.initial)
  }
  let controller = SlideIndexController(container: container) {
    CameraObscuraOrigin()
  }
  return SlideRouterView(slideIndexController: controller)
}

#Preview(".second") {
  let container = ObservableObjectContainer()
  _ = container.resolve {
    PhasedStateStore<CameraObscuraOrigin.SlidePhase>(.second)
  }
  let controller = SlideIndexController(container: container) {
    CameraObscuraOrigin()
  }
  return SlideRouterView(slideIndexController: controller)
}
