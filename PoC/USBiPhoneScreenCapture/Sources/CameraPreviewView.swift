import AVFoundation
import AppKit
import SwiftUI

struct CameraPreviewView: NSViewRepresentable {
  let session: AVCaptureSession

  func makeNSView(context: Context) -> PreviewNSView {
    let view = PreviewNSView()
    view.previewLayer.session = session
    view.previewLayer.videoGravity = .resizeAspect
    return view
  }

  func updateNSView(_ nsView: PreviewNSView, context: Context) {}
}

final class PreviewNSView: NSView {
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
