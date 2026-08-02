#if os(iOS)
  import Foundation
  import Photos
  import UniformTypeIdentifiers

  /// iPhone側: 撮影したHEICを自分のPhotosライブラリに保存する。
  /// macOS側では保存しない — 同じApple IDならiCloud Photo Library経由でいずれ
  /// Macのライブラリにも反映されるため、Mac側で別途保存すると写真が重複してしまう。
  enum PhotoLibrarySaver {
    enum SaveError: Error {
      case authorizationDenied
    }

    static func save(heicData: Data) async throws {
      let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
      guard status == .authorized || status == .limited else {
        throw SaveError.authorizationDenied
      }
      try await PHPhotoLibrary.shared().performChanges {
        let request = PHAssetCreationRequest.forAsset()
        let options = PHAssetResourceCreationOptions()
        options.uniformTypeIdentifier = UTType.heic.identifier
        request.addResource(with: .photo, data: heicData, options: options)
      }
    }
  }
#endif
