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
      VStack(spacing: 20) {
        // Feature B: Feature Aの同期コネクションに相乗りしたライブプレビュー。
        // シャッターを切る前から、iPhoneが今写しているものが分かる。
        if let frameData = syncCoordinator?.latestPreviewFrameData,
          let nsImage = NSImage(data: frameData)
        {
          Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 320)
          Text("ライブプレビュー")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

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

        Button("閉じる") {
          receiver.stop()
          dismiss()
        }
      }
      .padding(40)
      .frame(minWidth: 360, minHeight: 240)
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
  }
#endif
