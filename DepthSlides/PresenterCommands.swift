#if os(macOS)
  import SlideKit
  import SwiftUI

  struct PresenterCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    let slideIndexController: SlideIndexController

    var body: some Commands {
      CommandGroup(after: .undoRedo) {
        Button("Forward") { slideIndexController.forward() }
          .keyboardShortcut(.rightArrow, modifiers: [])
        Button("Forward") { slideIndexController.forward() }
          .keyboardShortcut(.return, modifiers: [])
        Button("Back") { slideIndexController.back() }
          .keyboardShortcut(.leftArrow, modifiers: [])
      }
      CommandGroup(after: .importExport) {
        Button("Export PDF") {
          Task {
            await SlidePDFExporter().exportWithSavePanel(slideIndexController: slideIndexController)
          }
        }
        .keyboardShortcut("e", modifiers: [.command])
      }
      CommandGroup(after: .windowList) {
        Button("Open Presenter") {
          openWindow(id: "presenter")
        }
        .keyboardShortcut("p", modifiers: [.command, .shift])
      }
    }
  }
#endif
