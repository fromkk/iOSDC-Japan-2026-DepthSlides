import CoreGraphics
import Foundation
import ImageIO

/// `ApertureSamples/` に同梱した「同じ被写体を f値 だけ変えて撮った」実写の連番。
/// LEICA M11-P + 35mm、f/1.4 から f/16 までハーフストップ刻みの15枚で、
/// 09_FNumberDemo のフェーズ2（絞りとボケの関係の実演）で自動再生する。
///
/// f値 は撮影時の実絞りをファイル名で持つ。マニュアルレンズなのでボディ側の
/// EXIF の f値 は当てにならず、ファイル名が唯一の正確な出典になっている。
enum ApertureSampleAssets {
  struct Sample: Identifiable, Sendable {
    let fNumber: Double
    let fileName: String

    var id: String { fileName }

    /// "f/1.4" / "f/16" のように、小数が意味を持つときだけ小数第1位まで出す。
    var label: String {
      fNumber < 10 && fNumber != fNumber.rounded()
        ? String(format: "f/%.1f", fNumber)
        : String(format: "f/%.0f", fNumber)
    }
  }

  /// 開放から絞り込みへ向かう順。再生もこの順で進む。
  static let samples: [Sample] = [
    Sample(fNumber: 1.4, fileName: "f1_4.jpg"),
    Sample(fNumber: 1.7, fileName: "f1_7.jpg"),
    Sample(fNumber: 2.0, fileName: "f2_0.jpg"),
    Sample(fNumber: 2.4, fileName: "f2_4.jpg"),
    Sample(fNumber: 2.8, fileName: "f2_8.jpg"),
    Sample(fNumber: 3.3, fileName: "f3_3.jpg"),
    Sample(fNumber: 4.0, fileName: "f4_0.jpg"),
    Sample(fNumber: 4.8, fileName: "f4_8.jpg"),
    Sample(fNumber: 5.6, fileName: "f5_6.jpg"),
    Sample(fNumber: 6.7, fileName: "f6_7.jpg"),
    Sample(fNumber: 8.0, fileName: "f8_0.jpg"),
    Sample(fNumber: 9.5, fileName: "f9_5.jpg"),
    Sample(fNumber: 11.0, fileName: "f11_0.jpg"),
    Sample(fNumber: 13.0, fileName: "f13_0.jpg"),
    Sample(fNumber: 16.0, fileName: "f16_0.jpg"),
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
        forResource: name, withExtension: ext, subdirectory: "ApertureSamples"),
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
