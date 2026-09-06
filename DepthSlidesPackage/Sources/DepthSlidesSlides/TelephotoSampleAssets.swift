import CoreGraphics
import Foundation
import ImageIO

/// `TelephotoSamples/` に同梱した「同じ場所から iPhone のレンズ（倍率）だけを
/// 切り替えて撮った」実写の連番。13_iPhonePhotoTips の作例として自動再生し、
/// 望遠側ほど背景（ビル）がボケることを見せる。
///
/// 元ファイルは IMG_3140（1x） → IMG_3137（2x） → IMG_3136（4x） → IMG_3135（8x）。
/// 35mm 判換算の焦点距離はメタデータから拾った値で、ファイル名にも持たせている。
enum TelephotoSampleAssets {
  struct Sample: Identifiable, Sendable {
    /// メインカメラ（24mm）を 1 とした倍率
    let zoom: Int
    /// 35mm 判換算焦点距離
    let focalLength: Int
    let fileName: String

    var id: String { fileName }

    /// "2x" のようにカメラアプリの表記に合わせる
    var zoomLabel: String { "\(zoom)x" }
    var focalLengthLabel: String { "\(focalLength)mm" }
  }

  /// 広角から望遠へ向かう順。再生もこの順で進む。
  static let samples: [Sample] = [
    Sample(zoom: 1, focalLength: 24, fileName: "x1_24mm.jpg"),
    Sample(zoom: 2, focalLength: 48, fileName: "x2_48mm.jpg"),
    Sample(zoom: 4, focalLength: 100, fileName: "x4_100mm.jpg"),
    Sample(zoom: 8, focalLength: 200, fileName: "x8_200mm.jpg"),
  ]

  /// 自動再生中に毎コマ読み直すとディスクI/Oとデコードで引っかかるため、
  /// スライド表示時に全コマまとめてデコードして持っておく前提の API。
  static func loadImages(maxPixelSize: Int = 1200) -> [CGImage] {
    samples.compactMap { cgImage(for: $0, maxPixelSize: maxPixelSize) }
  }

  static func cgImage(for sample: Sample, maxPixelSize: Int = 1200) -> CGImage? {
    let name = (sample.fileName as NSString).deletingPathExtension
    let ext = (sample.fileName as NSString).pathExtension
    guard
      let url = Bundle.module.url(
        forResource: name, withExtension: ext, subdirectory: "TelephotoSamples"),
      let source = CGImageSourceCreateWithURL(url as CFURL, nil)
    else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  }
}
