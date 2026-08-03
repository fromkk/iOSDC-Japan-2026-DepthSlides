import AVFoundation
import SwiftUI

/// `UVCCameraSession`のライブ映像を表示するだけのプレビュー。タップフォーカスや
/// シャッターなど`PeerCaptureCameraView`にある撮影系のUIは持たない。
struct UVCCameraPreviewView: View {
  let session: UVCCameraSession

  var body: some View {
    UVCCameraPreviewRepresentable(session: session.session)
  }
}

#if os(iOS)
  import UIKit

  private struct UVCCameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
      let view = PreviewUIView()
      view.previewLayer.session = session
      view.previewLayer.videoGravity = .resizeAspect
      return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
  }

  private final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
  }
#elseif os(macOS)
  import AppKit

  private struct UVCCameraPreviewRepresentable: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewNSView {
      let view = PreviewNSView()
      view.previewLayer.session = session
      view.previewLayer.videoGravity = .resizeAspect
      return view
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {}
  }

  private final class PreviewNSView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
      super.init(frame: frameRect)
      wantsLayer = true
      layer = previewLayer
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  }
#endif
