import CoreGraphics
import Foundation
import ImageIO

/// `DepthSamples/` に `.copy` で同梱したサンプル写真を読み込むヘルパー。
/// xcassets 経由の `Image(...)` と違い、AVDepthData の補助データを含む
/// 生のファイルデータが必要な場面（埋め込み深度の取得・深度推定のキャッシュキー）で使う。
enum DepthSampleAssets {
  enum Sample: String {
    /// ポートレートモードで撮影（視差マップ入り HEIC）
    case portraitWithDepth = "IMG_1606.heic"
    /// iPhone 17 Pro で普通に撮影したひまわり（深度なし JPEG）
    case sunflowerIPhone = "IMG_2569.jpeg"
  }

  static func data(for sample: Sample) -> Data? {
    let name = (sample.rawValue as NSString).deletingPathExtension
    let ext = (sample.rawValue as NSString).pathExtension
    guard
      let url = Bundle.module.url(
        forResource: name, withExtension: ext, subdirectory: "DepthSamples")
    else { return nil }
    return try? Data(contentsOf: url)
  }

  /// EXIF Orientation を適用した CGImage を返す。
  static func cgImage(from data: Data, maxPixelSize: Int = 2400) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  }
}
