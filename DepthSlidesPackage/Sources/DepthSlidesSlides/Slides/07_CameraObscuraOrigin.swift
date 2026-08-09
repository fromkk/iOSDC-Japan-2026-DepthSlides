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

  var body: some View {
    Group {
      switch phase {
      case .initial:
        HeaderSlide("カメラの元祖") {
          Spacer()
          Text(
            "出典: https://commons.wikimedia.org/wiki/File:1646_Athanasius_Kircher_-_Camera_obscura.jpg"
          )
          .font(.system(size: 32))
        }
        .background {
          Image(.cameraObscura)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(.bottom, 120)
        }
      case .second:
        HeaderSlide("Camera Obscura") {
          Spacer()
          Text(
            "出典: https://commons.wikimedia.org/wiki/File:Camera_Obscura_box18thCentury.jpg"
          )
          .font(.system(size: 32))
        }
        .background {
          Image(.cameraObscura2)
            .resizable()
            .aspectRatio(contentMode: .fit)
        }
      }
    }
  }

  var script: String {
    """
    カメラの原点は、紀元前400年ごろにさかのぼります。
    戦国時代の思想家・墨子の著作『墨経』に、暗い箱に小さな穴をあけると外の光が入り、逆さになって投影されることが記録されているらしいです。
    墨子は光がまっすぐ進むから像が逆さまになる、という理由まで正しく理解していたそうです。
    これを小さな暗い部屋という意味でカメラ・オブスキュラと呼ばれています。
    この仕組みを利用して15世紀ごろ、レオナルド・ダ・ヴィンチは写生に利用したとされています。
    当初はフィルムのような記録用途ではなく、トレーシングペーパーのような半透明な紙に投影させて、それをなぞって絵を描くために利用していました。
    """
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
