import AVFoundation
import ImageIO
import os.log

private let logger = Logger(subsystem: "info.fromkk.poc.USBiPhoneScreenCapture", category: "depth-read")

struct DepthReadResult {
  let auxDataType: String
  let depthDataType: String
  let width: Int
  let height: Int
  let quality: String
  let accuracy: String
}

struct DepthReadError: Error {
  let message: String
}

enum DepthFileReader {
  // 撮影済みHEIF/JPEGファイルに埋め込まれたDepth/DisparityをImageIO+AVDepthDataで読み出す。
  // ライブキャプチャ時のisDepthDataDeliveryEnabled等とは別物で、macOSでも利用可能なはず。
  static func read(from url: URL) -> Result<DepthReadResult, DepthReadError> {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      return .failure(DepthReadError(message: "CGImageSourceの作成に失敗しました"))
    }

    for auxType in [kCGImageAuxiliaryDataTypeDepth, kCGImageAuxiliaryDataTypeDisparity] {
      guard
        let auxDict = CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, auxType)
          as? [AnyHashable: Any]
      else {
        continue
      }
      logger.log("found aux data type=\(auxType as String, privacy: .public)")
      do {
        let depthData = try AVDepthData(fromDictionaryRepresentation: auxDict)
        let map = depthData.depthDataMap
        let width = CVPixelBufferGetWidth(map)
        let height = CVPixelBufferGetHeight(map)
        let quality = depthData.depthDataQuality == .high ? "high" : "low"
        let accuracy = depthData.depthDataAccuracy == .absolute ? "absolute" : "relative"
        let result = DepthReadResult(
          auxDataType: auxType as String,
          depthDataType: fourCharString(depthData.depthDataType),
          width: width,
          height: height,
          quality: quality,
          accuracy: accuracy
        )
        logger.log(
          "AVDepthData decoded: type=\(result.depthDataType, privacy: .public) size=\(width, privacy: .public)x\(height, privacy: .public) quality=\(quality, privacy: .public) accuracy=\(accuracy, privacy: .public)"
        )
        return .success(result)
      } catch {
        logger.error(
          "AVDepthData(fromDictionaryRepresentation:) failed: \(error.localizedDescription, privacy: .public)"
        )
        return .failure(DepthReadError(message: "AVDepthDataへの変換に失敗: \(error.localizedDescription)"))
      }
    }
    return .failure(DepthReadError(message: "このファイルにはDepth/Disparityの補助データが見つかりませんでした"))
  }

  private static func fourCharString(_ value: OSType) -> String {
    let bytes: [UInt8] = [
      UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF),
      UInt8(value & 0xFF),
    ]
    return String(bytes: bytes, encoding: .ascii) ?? "\(value)"
  }
}
