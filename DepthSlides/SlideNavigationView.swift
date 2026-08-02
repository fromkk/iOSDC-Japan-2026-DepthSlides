#if canImport(UIKit)
  import DepthSlidesSlides
  import SlideKit
  import SwiftUI

  struct SlideNavigationView: View {
    let configuration: SlideConfiguration
    var store: AppStore?
    @ObservedObject private var slideIndexController: SlideIndexController
    @Environment(\.presentationSyncCoordinator) private var syncCoordinator
    @FocusState private var isFocused: Bool
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showShareSheet = false

    init(configuration: SlideConfiguration, store: AppStore? = nil) {
      self.configuration = configuration
      self.store = store
      self.slideIndexController = configuration.slideIndexController
    }

    // ページ送りは必ずここを経由させる。`slideIndexController.forward()/back()`を
    // 直接呼ぶと、スライド内Phaseだけが進むケースが同期されなくなる。
    private func stepForward() {
      if let syncCoordinator {
        syncCoordinator.forward()
      } else {
        configuration.slideIndexController.forward()
      }
    }

    private func stepBack() {
      if let syncCoordinator {
        syncCoordinator.back()
      } else {
        configuration.slideIndexController.back()
      }
    }

    /// 押し間違い等でMacとズレたときに、接続中のMacの現在位置に合わせ直す。
    private func syncFromMac() {
      syncCoordinator?.syncFromMaster()
    }

    var body: some View {
      if let store, store.hasExternalDisplay, !store.isMirroring {
        presenterView(store: store)
      } else {
        slideView(store: store)
      }
    }

    private func startExport() {
      isExporting = true
      Task {
        let url = await SlidePDFExporter().export(
          slideIndexController: configuration.slideIndexController)
        exportURL = url
        isExporting = false
        showShareSheet = url != nil
      }
    }

    // MARK: - Full-screen slide view

    private func slideView(store: AppStore? = nil) -> some View {
      ZStack(alignment: .topTrailing) {
        PresentationView(slideSize: configuration.size) {
          SlideRouterView(slideIndexController: slideIndexController)
        }
        .gesture(navigationGesture)
        .focusable()
        .focusEffectDisabled(true)
        .focused($isFocused)
        .onKeyPress(.rightArrow) {
          Task { @MainActor in stepForward() }
          return .handled
        }
        .onKeyPress(.leftArrow) {
          Task { @MainActor in stepBack() }
          return .handled
        }
        .onKeyPress(.space) {
          Task { @MainActor in stepForward() }
          return .handled
        }
        .onAppear {
          isFocused = true
        }
        .sheet(isPresented: $showShareSheet) {
          if let url = exportURL {
            ActivityView(items: [url])
          }
        }

        HStack(spacing: 8) {
          Button {
            startExport()
          } label: {
            if isExporting {
              ProgressView()
                .tint(Color(.label))
            } else {
              Label("Export PDF", systemImage: "doc.badge.arrow.up")
                .labelStyle(.iconOnly)
            }
          }
          .tint(Color(.label))
          .buttonStyle(.glass)
          .disabled(isExporting)

          Button {
            syncFromMac()
          } label: {
            Label("Macと同期", systemImage: "arrow.triangle.2.circlepath")
              .labelStyle(.iconOnly)
          }
          .tint(Color(.label))
          .buttonStyle(.glass)

          if let store, store.hasExternalDisplay {
            Button {
              store.isMirroring.toggle()
            } label: {
              Label("Presentation Mode", systemImage: "rectangle.on.rectangle")
                .labelStyle(.iconOnly)
            }
            .tint(Color(.label))
            .buttonStyle(.glass)
          }
        }
        .padding()
      }
    }

    // MARK: - Presenter view (external display connected)

    private func presenterView(store: AppStore) -> some View {
      NavigationStack {
        VStack(spacing: 0) {
          PresentationView(slideSize: configuration.size) {
            SlideRouterView(slideIndexController: slideIndexController)
          }
          .aspectRatio(16 / 9, contentMode: .fit)
          .padding()

          ScrollView {
            Text(
              slideIndexController.currentScript.isEmpty
                ? "（スピーカーノートなし）" : slideIndexController.currentScript
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .padding()
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .gesture(navigationGesture)
        .focusable()
        .focusEffectDisabled(true)
        .focused($isFocused)
        .onKeyPress(.rightArrow) {
          Task { @MainActor in stepForward() }
          return .handled
        }
        .onKeyPress(.leftArrow) {
          Task { @MainActor in stepBack() }
          return .handled
        }
        .onKeyPress(.space) {
          Task { @MainActor in stepForward() }
          return .handled
        }
        .onAppear {
          isFocused = true
        }
        .sheet(isPresented: $showShareSheet) {
          if let url = exportURL {
            ActivityView(items: [url])
          }
        }
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button {
              store.isMirroring.toggle()
            } label: {
              Label(
                store.isMirroring ? "Presentation Mode" : "Mirror Mode",
                systemImage: store.isMirroring ? "rectangle.on.rectangle" : "rectangle.2.swap"
              )
            }
          }

          ToolbarItem(placement: .primaryAction) {
            Button {
              startExport()
            } label: {
              if isExporting {
                ProgressView()
              } else {
                Label("Export PDF", systemImage: "doc.badge.arrow.up")
              }
            }
            .disabled(isExporting)
          }

          ToolbarItem(placement: .primaryAction) {
            Button {
              syncFromMac()
            } label: {
              Label("Macと同期", systemImage: "arrow.triangle.2.circlepath")
            }
          }

          ToolbarItem(placement: .bottomBar) {
            Button {
              stepBack()
            } label: {
              Label("Back", systemImage: "chevron.backward")
            }
          }

          ToolbarItem(placement: .bottomBar) {
            Text(
              "\(slideIndexController.currentIndex + 1) / \(slideIndexController.slides.count)"
            )
            .monospacedDigit()
            .fixedSize()
          }

          ToolbarItem(placement: .bottomBar) {
            Button {
              stepForward()
            } label: {
              Label("Next", systemImage: "chevron.forward")
            }
          }
        }
      }
    }

    // MARK: - Shared gesture

    private var navigationGesture: some Gesture {
      DragGesture(minimumDistance: 100)
        .onEnded { value in
          if value.translation.width < 100 {
            stepForward()
          } else if value.translation.width > -100 {
            stepBack()
          }
        }
    }
  }
#endif
