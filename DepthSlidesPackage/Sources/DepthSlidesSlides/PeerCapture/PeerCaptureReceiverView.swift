#if os(macOS)
  import AppKit
  import SwiftUI

  /// Mac側: iPhoneからの受信待ち状態を表示する。受信できたら
  /// `onReceived`クロージャ経由で`DepthModelCompareView`へDataを渡す。
  struct PeerCaptureReceiverView: View {
    var onReceived: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
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
          Color.black.ignoresSafeArea()
          Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

          VStack {
            Spacer()
            statusOverlay
          }
        } else {
          VStack(spacing: 20) {
            statusBody
          }
          .padding(40)
        }

        VStack {
          HStack {
            Spacer()
            Button {
              receiver.stop()
              dismiss()
            } label: {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(syncCoordinator?.latestPreviewFrameData != nil ? .white : .primary)
            }
            .buttonStyle(.plain)
            .padding()
          }
          Spacer()
        }
      }
      .frame(minWidth: 480, minHeight: 360)
      .task {
        receiver.start()
      }
      .onChange(of: receiver.state) { _, newState in
        if case .received(let data) = newState {
          onReceived(data)
          receiver.acknowledgeReceived()
          dismiss()
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
        Text("iPhoneを探しています...\n「このiPhoneで撮影」から送信してください")
          .multilineTextAlignment(.center)
      case .receiving:
        ProgressView()
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
        .padding(10)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        .foregroundStyle(.white)
        .padding(.bottom, 24)
    }
  }
#endif
