#if os(macOS)
  import DepthSlidesSlides
  import SlideKit
  import SwiftUI

  struct PresenterCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    let slideIndexController: SlideIndexController
    let syncCoordinator: PresentationSyncCoordinator

    var body: some Commands {
      CommandGroup(after: .undoRedo) {
        Button("Forward") { syncCoordinator.forward() }
          .keyboardShortcut(.rightArrow, modifiers: [])
        Button("Forward") { syncCoordinator.forward() }
          .keyboardShortcut(.return, modifiers: [])
        Button("Back") { syncCoordinator.back() }
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
