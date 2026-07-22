import AVFoundation
import CoreImage
import ImageIO

/// 写真自体に埋め込まれた AVDepthData（Portrait Mode などが記録する視差/深度マップ）
/// を取り出す。Core ML 推論とは無関係な純粋なデータ抽出処理なので、
/// `DepthEstimator` actor には入れず独立させている
/// （`DepthModel.embeddedDepth` 用に `DepthModelCompareView` から呼ばれる）。
enum EmbeddedDepthExtractor {
  enum ExtractionError: Error {
    case sourceCreationFailed
    case noEmbeddedDepthData
    case imageRenderFailed
  }

  private static let context = CIContext()

  static func extractDepthImage(from imageData: Data) throws -> CGImage {
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
      throw ExtractionError.sourceCreationFailed
    }
    guard let depthData = auxiliaryDepthData(from: source) else {
      throw ExtractionError.noEmbeddedDepthData
    }

    // 視差(disparity)形式に統一する（近い = 値が大きい = 明るい。他モデルと同じ規約）。
    let converted = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
    var depthImage = CIImage(cvPixelBuffer: converted.depthDataMap)

    // 深度マップはセンサーの生の向きで格納されているため、本体画像の EXIF
    // Orientation を読み取って同じ回転を適用しないと縦写真が横向きになる。
    if let orientation = exifOrientation(from: source) {
      depthImage = depthImage.oriented(orientation)
    }

    guard let cgImage = context.createCGImage(depthImage, from: depthImage.extent) else {
      throw ExtractionError.imageRenderFailed
    }
    return cgImage
  }

  private static func auxiliaryDepthData(from source: CGImageSource) -> AVDepthData? {
    for auxType in [kCGImageAuxiliaryDataTypeDepth, kCGImageAuxiliaryDataTypeDisparity]
      as [CFString]
    {
      guard
        let info = CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, auxType)
          as? [AnyHashable: Any],
        let depthData = try? AVDepthData(fromDictionaryRepresentation: info)
      else { continue }
      return depthData
    }
    return nil
  }
}
