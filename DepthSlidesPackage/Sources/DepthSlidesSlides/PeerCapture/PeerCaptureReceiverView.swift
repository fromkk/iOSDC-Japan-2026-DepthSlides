#if os(macOS)
  import AppKit
  import SwiftUI

  /// Mac側: iPhoneからの受信待ち状態を表示する。受信できたら
  /// `onReceived`クロージャ経由で`DepthModelCompareView`へDataを渡す。
  ///
  /// sheet ではなくスライドの上に重ねて表示する（スライド座標系で 1920×1080 に
  /// 拡縮されるため、文字サイズはスライド内の他の要素と同じ尺度で指定する）。
  /// 閉じる操作は `onClose` で親に返し、表示状態は親が持つ。
  struct PeerCaptureReceiverView: View {
    var onReceived: (Data) -> Void
    var onClose: () -> Void

    @Environment(\.presentationSyncCoordinator) private var syncCoordinator
    @State private var receiver = PeerCaptureReceiver()

    var body: some View {
      ZStack {
        // Feature B: Feature Aの同期コネクションに相乗りしたライブプレビューが
        // 届いている間は、それを画面いっぱいに表示する(縦横どちらの向きでも
        // aspectRatio(.fit)で収まる)。「探しています」等のステータス文言は
        // 実際に映像が来ているのに出ると違和感があるので、プレビューが無い
        // 間だけ表示する。
        if let frameData = syncCoordinator?.latestPreviewFrameData,
          let nsImage = NSImage(data: frameData)
        {
          Color.black
          Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

          VStack {
            Spacer()
            statusOverlay
          }
        } else {
          VStack(spacing: 28) {
            statusBody
          }
          .font(.system(size: 28))
          .padding(40)
        }

        VStack {
          HStack {
            Spacer()
            Button {
              receiver.stop()
              onClose()
            } label: {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(syncCoordinator?.latestPreviewFrameData != nil ? .white : .primary)
            }
            .buttonStyle(.plain)
            .padding(20)
          }
          Spacer()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .task {
        receiver.start()
      }
      .onChange(of: receiver.state) { _, newState in
        if case .received(let data) = newState {
          onReceived(data)
          receiver.acknowledgeReceived()
        }
      }
      .onDisappear {
        receiver.stop()
      }
    }

    /// プレビューが無いときに中央に出す、状態そのものの表示。
    @ViewBuilder
    private var statusBody: some View {
      switch receiver.state {
      case .idle, .listening:
        ProgressView()
          .controlSize(.large)
        Text("iPhoneを探しています...\n「このiPhoneで撮影」から送信してください")
          .multilineTextAlignment(.center)
      case .receiving:
        ProgressView()
          .controlSize(.large)
        Text("写真を受信中...")
      case .received:
        Text("写真を受信しました")
      case .failed(let message):
        Text(message)
          .foregroundStyle(.red)
        Button("再試行") {
          receiver.stop()
          receiver.start()
        }
      }
    }

    /// プレビュー表示中に、下部へ小さく重ねる補足ステータス。
    /// 単に「探しています」を隠すだけでなく、受信中/失敗は伝える必要があるため。
    @ViewBuilder
    private var statusOverlay: some View {
      switch receiver.state {
      case .receiving:
        overlayLabel {
          HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("写真を受信中...")
          }
        }
      case .failed(let message):
        overlayLabel {
          VStack(spacing: 8) {
            Text(message).foregroundStyle(.red)
            Button("再試行") {
              receiver.stop()
              receiver.start()
            }
          }
        }
      case .idle, .listening, .received:
        EmptyView()
      }
    }

    private func overlayLabel(@ViewBuilder content: () -> some View) -> some View {
      content()
        .font(.system(size: 24))
        .padding(16)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(.white)
        .padding(.bottom, 32)
    }
  }
#endif
