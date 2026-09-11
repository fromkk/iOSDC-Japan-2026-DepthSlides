#if os(iOS)
  import AVFoundation
  import AVKit
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
    // Depthを保ったまま選べる範囲は機種・フォーマット依存で、固定の「24mm/35mm」等の
    // ラベルでは選択肢として成立しない(選んでも同じ値にスナップされてしまう)ことが
    // 実機検証で分かった。そのため実際にDepthが使える範囲から動的にプリセットを作る。
    @State private var depthSafeFocalLengthRange: ClosedRange<CGFloat>?
    @State private var selectedFocalLengthMM: CGFloat?
    /// カメラコントロールの UI が全画面表示になっているあいだは true。
    /// Apple のガイドラインに従い、このあいだは自前のシャッターや焦点距離ピッカーを
    /// 隠してプレビューを遮らないようにする。
    @State private var isCameraControlFullscreen = false

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
          CameraPreviewView(cameraSession: session)
            .ignoresSafeArea()
        }

        captureEventReceiver

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

            if let depthSafeFocalLengthRange {
              HStack(spacing: 4) {
                ForEach(focalLengthPresets(for: depthSafeFocalLengthRange), id: \.self) { mm in
                  Button {
                    selectedFocalLengthMM = mm
                    session.setZoom(toFocalLengthMM: mm)
                  } label: {
                    Text("\(Int(mm.rounded()))mm")
                      .font(.system(size: 14, weight: .semibold))
                      .foregroundStyle(selectedFocalLengthMM == mm ? .black : .white)
                      .padding(.horizontal, 12)
                      .padding(.vertical, 6)
                      .background(
                        selectedFocalLengthMM == mm ? Color.white : Color.black.opacity(0.4),
                        in: Capsule()
                      )
                  }
                }
              }
              .padding()
            }
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
        .opacity(isCameraControlFullscreen ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: isCameraControlFullscreen)
      }
      .task {
        do {
          try session.configure()
          session.startRunning()
          startForwardingPreview()
          // configure()内で既にDepth対応範囲の中で「1倍に最も近い値」へズームが
          // 合わせられているが、それは丸めていない生の値なのでプリセット(丸めた値)とは
          // 一致しない。プリセットのうち最初の1つ(下限に最も近いもの)へ実際に
          // 合わせ直し、UIの選択状態とも揃える。
          var presets: [CGFloat] = []
          if let range = session.depthSafeFocalLengthRangeMM {
            depthSafeFocalLengthRange = range
            presets = focalLengthPresets(for: range)
            if let firstPreset = presets.first {
              selectedFocalLengthMM = firstPreset
              session.setZoom(toFocalLengthMM: firstPreset)
            }
          }
          configureCameraControls(focalLengths: presets)
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

    /// iPhone 16 以降のカメラコントロール(本体側面のボタン)。軽く押すと露出補正と
    /// 焦点距離のコントロールが出て、押し込むとシャッターが切れる。
    /// 焦点距離は画面内のプリセットと同じ「Depth を保てる値」だけを出す。
    private func configureCameraControls(focalLengths: [CGFloat]) {
      guard session.supportsCameraControls else { return }
      session.onControlsFullscreenAppearanceChanged = { isFullscreen in
        isCameraControlFullscreen = isFullscreen
      }
      session.onFocalLengthSelectedFromControl = { millimeters in
        selectedFocalLengthMM = millimeters
      }
      session.configureCameraControls(focalLengthsMM: focalLengths, selectedIndex: 0)
    }

    /// ハードウェアシャッター(カメラコントロールの押し込み、音量ボタン)を受ける
    /// 透明なビュー。撮影済みプレビューを出しているあいだは無効にして、
    /// システム標準のボタン動作へ戻す(`AVCaptureEventInteraction` のドキュメントが
    /// 「反応できないときは isEnabled を false にせよ」と明示している)。
    private var captureEventReceiver: some View {
      CaptureEventReceiver(isEnabled: capturedData == nil && configurationError == nil) {
        Task { await capturePhoto() }
      }
      .allowsHitTesting(false)
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

    /// 実機で計算した生の範囲(例: 34mm〜170mm)をそのまま出すと馴染みの薄い値になるため、
    /// 実際のレンズでよくある焦点距離の中から最も近いものに丸めて表示・設定する。
    private static let niceFocalLengthsMM: [CGFloat] = [
      14, 15, 18, 20, 24, 28, 35, 50, 65, 85, 105, 135, 150, 170, 200, 300, 400, 500, 600, 800,
    ]

    private func focalLengthPresets(for range: ClosedRange<CGFloat>) -> [CGFloat] {
      let mid = (range.lowerBound + range.upperBound) / 2
      let rawTargets = [range.lowerBound, mid, range.upperBound]
      var seen = Set<CGFloat>()
      return rawTargets.compactMap { raw in
        let nice = Self.niceFocalLengthsMM.min(by: { abs($0 - raw) < abs($1 - raw) }) ?? raw
        guard seen.insert(nice).inserted else { return nil }
        return nice
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
    let cameraSession: PeerCaptureCameraSession

    func makeUIView(context: Context) -> PreviewUIView {
      let view = PreviewUIView()
      view.previewLayer.session = cameraSession.session
      view.previewLayer.videoGravity = .resizeAspectFill
      // 縦横どちらの向きでも正しく表示されるよう、実在するpreviewLayerを
      // セッション側の回転コーディネーターに渡す(詳細はPeerCaptureCameraSession参照)。
      cameraSession.attachPreviewLayer(view.previewLayer)

      let tapGesture = UITapGestureRecognizer(
        target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
      view.addGestureRecognizer(tapGesture)
      context.coordinator.previewView = view

      return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
      Coordinator(cameraSession: cameraSession)
    }

    @MainActor
    final class Coordinator: NSObject {
      let cameraSession: PeerCaptureCameraSession
      weak var previewView: PreviewUIView?

      init(cameraSession: PeerCaptureCameraSession) {
        self.cameraSession = cameraSession
      }

      @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let previewView else { return }
        let layerPoint = gesture.location(in: previewView)
        let devicePoint = previewView.previewLayer.captureDevicePointConverted(
          fromLayerPoint: layerPoint)
        cameraSession.focus(at: devicePoint)
        previewView.showFocusIndicator(at: layerPoint)
      }
    }
  }

  private final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    /// タップ・フォーカス位置を示す黄色い枠を一瞬表示して消す、標準的なカメラアプリの
    /// フィードバックを再現する。
    func showFocusIndicator(at point: CGPoint) {
      let size: CGFloat = 70
      let indicator = UIView(
        frame: CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size))
      indicator.layer.borderColor = UIColor.systemYellow.cgColor
      indicator.layer.borderWidth = 1.5
      indicator.layer.cornerRadius = 4
      indicator.alpha = 0
      indicator.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
      addSubview(indicator)

      UIView.animate(
        withDuration: 0.15,
        animations: {
          indicator.alpha = 1
          indicator.transform = .identity
        },
        completion: { _ in
          UIView.animate(
            withDuration: 0.4, delay: 0.5, options: [],
            animations: { indicator.alpha = 0 },
            completion: { _ in indicator.removeFromSuperview() })
        })
    }
  }

  /// `AVCaptureEventInteraction` を載せるだけの透明なビュー。SwiftUI に同等の
  /// 修飾子が無いため UIKit の interaction を直接使う。
  private struct CaptureEventReceiver: UIViewRepresentable {
    var isEnabled: Bool
    var onCapture: () -> Void

    func makeUIView(context: Context) -> UIView {
      let view = UIView()
      view.isUserInteractionEnabled = false
      view.backgroundColor = .clear

      let coordinator = context.coordinator
      coordinator.onCapture = onCapture
      // 押し始め(.began)でも呼ばれるので、押し終わりだけを拾って二重撮影を避ける。
      let interaction = AVCaptureEventInteraction { event in
        guard event.phase == .ended else { return }
        Task { @MainActor in coordinator.onCapture?() }
      }
      interaction.isEnabled = isEnabled
      view.addInteraction(interaction)
      coordinator.interaction = interaction
      return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
      context.coordinator.onCapture = onCapture
      context.coordinator.interaction?.isEnabled = isEnabled
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
      var interaction: AVCaptureEventInteraction?
      var onCapture: (() -> Void)?
    }
  }
#endif
