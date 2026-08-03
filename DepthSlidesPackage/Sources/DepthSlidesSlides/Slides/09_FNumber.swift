import MarkdownToSlide
import SlideKit
import SwiftUI

@Slide
struct FNumber: View {
  @Environment(\.slideTheme) var slideTheme

  let converter = MarkdownToSlideConverter()

  @State private var uvcSession = UVCCameraSession()
  @State private var isShowingUVCPreview = false

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 16) {
        SlideWrapper {
          converter.convertPage(
            """
            # f値

            - レンズをそのまま使うと明るすぎる問題がある
              - 拡散や収差の問題で画像がにじんでしまう
              - 明るすぎると被写界深度が浅くなる
                - ピントを合わせるのが大変
                - ピントが合わない箇所（ボケ）が大きくなる
            - 絞りを使うことで入る光を制限する
              - 被写界深度を深くすることができる
              - ピントを合わせるのが簡単になる
              - ピントが合わない箇所（ボケ）が小さくなる
            - f値 = 焦点距離 / 絞りの実直径
            """
          )
        }
      }

      if uvcSession.isAvailable {
        VStack {
          // トグルのたびにUVCCameraPreviewViewをツリーから外し／戻すと、その都度
          // AVCaptureVideoPreviewLayerが生成し直され、直前のレイヤーの後始末と
          // 新しいレイヤーのsession接続がタイミングによっては競合し、まれに
          // 何も映らない状態になることを確認した。表示中かどうかに関わらず
          // Viewはツリーに残したまま、見た目だけをopacity/frameで切り替える。
          UVCCameraPreviewView(session: uvcSession)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .frame(width: isShowingUVCPreview ? 800 : 0)
            .opacity(isShowingUVCPreview ? 1 : 0)
            .padding(.trailing, isShowingUVCPreview ? slideTheme.contentPadding : 0)

          if !isShowingUVCPreview {
            Spacer()
          }

          Button(isShowingUVCPreview ? "カメラの入力を隠す" : "カメラの入力を表示") {
            isShowingUVCPreview.toggle()
          }
        }
      }
    }
    .padding(slideTheme.contentPadding)
    .onAppear {
      uvcSession.startMonitoring()
    }
    .onDisappear {
      uvcSession.stopMonitoring()
    }
    .onChange(of: uvcSession.isAvailable) { _, isAvailable in
      if !isAvailable {
        isShowingUVCPreview = false
      }
    }
  }

  var script: String = """
    レンズで光を集められるようになると、今度は明るすぎるという問題が出てきます。
    拡散や収差の影響で画像がにじんでしまったり、被写界深度が浅くなってピントを合わせるのが大変になったり、ピントが合わない箇所、つまりボケが大きくなったりします。
    そこで絞りを使って、入ってくる光を制限します。
    絞ることで被写界深度が深くなり、ピントを合わせるのが簡単になって、ボケも小さくなります。
    この絞り具合を表すのが f値 で、焦点距離を絞りの実直径で割った値です。
    """

  var transition: AnyTransition = AnyTransition(AwesomeTransition())
}

#Preview {
  SlidePreview {
    FNumber()
  }
}
