import SlideKit
import SwiftUI

@Slide
struct AboutCamera: View {
  @Phase
  var phase: SlidePhase

  enum SlidePhase: Int, PhasedState, Comparable {
    case initial
    case lens
    case sensor
    case storage
    case largeLens

    static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.rawValue < rhs.rawValue
    }
  }

  var body: some View {
    HeaderSlide("カメラって？") {
      HStack(spacing: 32) {
        VStack {
          Image(.camera)
          Text("https://www.irasutoya.com/2013/01/blog-post_3939.html")
            .font(.body)
        }

        VStack(alignment: .leading) {
          if phase >= .lens {
            Item {
              Text("レンズ")
                .font(
                  .system(size: phase == .largeLens ? 120 : 60)
                )
            }
          }
          if phase >= .sensor {
            Item {
              Text("センサー")
                .font(
                  .system(size: phase == .largeLens ? 120 : 60)
                )
            }
          }
          if phase >= .storage {
            Item {
              Text("ストレージ")
                .font(.system(size: 60))
            }
          }

          Spacer()
        }
      }
      .animation(.default, value: phase)
    }
  }

  var transition: AnyTransition = AnyTransition.awesome

  var script: String {
    switch phase {
    case .initial:
      return "自己紹介でカメラで写真を撮るのが好きと言いましたが、ここではカメラの構成要素を振り返ってみようと思います。"
    case .lens:
      return "まず、レンズをから光を取り込み"
    case .sensor:
      return "それをセンサーで受け取ります。"
    case .storage:
      return "センサーで受けた光情報をストレージに保存します。"
    case .largeLens:
      return "今回はこのレンズ・センサー部分についてお話します。"
    }
  }
}

#Preview {
  SlidePreview {
    AboutCamera()
  }
}
