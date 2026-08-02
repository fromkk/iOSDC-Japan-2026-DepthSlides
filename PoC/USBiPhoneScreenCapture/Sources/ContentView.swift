import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @StateObject private var controller = ScreenCaptureController()
  @State private var depthReadMessage: String = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("iPhone Continuity Camera PoC")
        .font(.headline)

      Picker(
        "デバイス",
        selection: Binding(
          get: { controller.selectedDeviceID ?? "" },
          set: { controller.selectedDeviceID = $0 }
        )
      ) {
        if controller.devices.isEmpty {
          Text("デバイスが見つかりません").tag("")
        }
        ForEach(controller.devices, id: \.uniqueID) { device in
          Text(device.localizedName).tag(device.uniqueID)
        }
      }
      .disabled(controller.devices.isEmpty)

      HStack {
        Button("デバイス再検索") { controller.refreshDevices() }
        Button(controller.isRunning ? "停止" : "開始") {
          if controller.isRunning {
            controller.stop()
          } else {
            controller.requestAccessAndStart()
          }
        }
        .disabled(controller.selectedDeviceID == nil)
        Button("写真を撮影") { controller.capturePhoto() }
          .disabled(!controller.isRunning)
      }

      Text(controller.statusMessage)
        .font(.caption)
        .foregroundStyle(.secondary)

      if let lastPhotoURL = controller.lastPhotoURL {
        HStack {
          Text("最新の撮影: \(lastPhotoURL.lastPathComponent)")
            .font(.caption)
          Button("Finderで表示") {
            NSWorkspace.shared.activateFileViewerSelecting([lastPhotoURL])
          }
        }
      }

      CameraPreviewView(session: controller.session)
        .frame(minWidth: 480, minHeight: 320)
        .background(Color.black)

      Divider()

      HStack {
        Button("HEIC/JPEGを選んでDepthを解析") { pickAndReadDepth() }
        Text(depthReadMessage)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding()
    .frame(minWidth: 560, minHeight: 560)
  }

  private func pickAndReadDepth() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.allowedContentTypes = [.heic, .heif, .jpeg]
    guard panel.runModal() == .OK, let url = panel.url else { return }

    switch DepthFileReader.read(from: url) {
    case .success(let result):
      depthReadMessage =
        "✅ \(result.auxDataType.replacingOccurrences(of: "kCGImageAuxiliaryDataType", with: "")) 検出: \(result.depthDataType) \(result.width)x\(result.height) quality=\(result.quality) accuracy=\(result.accuracy)"
    case .failure(let error):
      depthReadMessage = "❌ \(error.message)"
    }
  }
}
