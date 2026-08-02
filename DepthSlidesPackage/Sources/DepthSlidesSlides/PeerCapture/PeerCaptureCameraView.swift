#if os(iOS)
  import AVFoundation
  import SwiftUI
  import UIKit

  /// iPhone側: ライブプレビュー + シャッター + 送信のフルスクリーンUI。
  /// `DepthModelCompareView`とは`onCaptured`クロージャのみで疎結合。
  struct PeerCaptureCameraView: View {
    var onCaptured: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.presentationSyncCoordinator) private var syncCoordinator

    @State private var session = PeerCaptureCameraSession()
    @State private var sender = PeerCaptureSender()
    @State private var capturedData: Data?
    @State private var statusMessage = ""
    @State private var configurationError: String?
    @State private var previewForwardingTask: Task<Void, Never>?

    var body: some View {
      ZStack {
        Color.black.ignoresSafeArea()

        if let configurationError {
          VStack(spacing: 16) {
            Text(configurationError)
              .foregroundStyle(.white)
              .multilineTextAlignment(.center)
              .padding()
            Button("閉じる") { dismiss() }
              .buttonStyle(.borderedProminent)
          }
        } else {
          CameraPreviewView(session: session.session)
            .ignoresSafeArea()
        }

        VStack {
          HStack {
            Button {
              session.stopRunning()
              previewForwardingTask?.cancel()
              dismiss()
            } label: {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white)
            }
            .padding()
            Spacer()
          }

          Spacer()

          if !statusMessage.isEmpty {
            Text(statusMessage)
              .foregroundStyle(.white)
              .padding(8)
              .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
              .padding(.bottom, 8)
          }

          if capturedData != nil {
            HStack(spacing: 24) {
              Button("撮り直す") {
                capturedData = nil
                statusMessage = ""
              }
              .buttonStyle(.bordered)
              .tint(.white)

              Button("送信") {
                Task { await sendCapturedPhoto() }
              }
              .buttonStyle(.borderedProminent)
              .disabled(isSending)
            }
            .padding(.bottom, 40)
          } else if configurationError == nil {
            Button {
              Task { await capturePhoto() }
            } label: {
              Circle()
                .strokeBorder(.white, lineWidth: 4)
                .frame(width: 72, height: 72)
            }
            .padding(.bottom, 40)
          }
        }
      }
      .task {
        do {
          try session.configure()
          session.startRunning()
          startForwardingPreview()
        } catch {
          configurationError = "Depth撮影に対応したカメラが見つかりませんでした"
        }
      }
      .onChange(of: scenePhase) { _, newPhase in
        if newPhase != .active, capturedData == nil {
          session.stopRunning()
          previewForwardingTask?.cancel()
          dismiss()
        }
      }
      .onDisappear {
        session.stopRunning()
        previewForwardingTask?.cancel()
      }
    }

    /// Feature B: 撮影中のライブ映像を、Feature Aで既に確立済みの同期コネクションに
    /// 相乗りさせてMacへ送る。Mac未接続なら`syncCoordinator?.sendPreviewFrame`が
    /// 何もしないだけなので、ここでの分岐は不要。
    private func startForwardingPreview() {
      previewForwardingTask = Task {
        for await frame in session.previewFrames {
          syncCoordinator?.sendPreviewFrame(frame)
        }
      }
    }

    private var isSending: Bool {
      switch sender.state {
      case .discovering, .found, .sending: return true
      default: return false
      }
    }

    private func capturePhoto() async {
      statusMessage = "撮影中..."
      do {
        let data = try await session.capturePhotoVerifyingDepth()
        capturedData = data
        statusMessage = "Depth情報を確認しました"
      } catch PeerCaptureCameraSession.CaptureError.depthNotEmbedded {
        statusMessage = "この写真にはDepth情報が含まれていませんでした。被写体との距離を近づけて撮り直してください"
      } catch {
        statusMessage = "撮影に失敗しました: \(error.localizedDescription)"
      }
    }

    private func sendCapturedPhoto() async {
      guard let capturedData else { return }
      await sender.discoverAndSend(heicData: capturedData)
      switch sender.state {
      case .sent:
        onCaptured(capturedData)
        Task.detached(priority: .utility) {
          try? await PhotoLibrarySaver.save(heicData: capturedData)
        }
      case .discovering:
        statusMessage = "Macを探しています..."
      case .found(let name):
        statusMessage = "見つかりました: \(name)"
      case .sending:
        statusMessage = "送信中..."
      case .failed(let message):
        statusMessage = message
      case .idle:
        break
      }
    }
  }

  private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
      let view = PreviewUIView()
      view.previewLayer.session = session
      view.previewLayer.videoGravity = .resizeAspectFill
      return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
  }

  private final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
  }
#endif
