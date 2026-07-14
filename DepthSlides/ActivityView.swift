#if canImport(UIKit)
  import SwiftUI
  import UIKit

  struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
      let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
      return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
  }
#endif
