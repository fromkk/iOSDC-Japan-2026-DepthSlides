import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// URL 文字列から QR コード画像を作る。イベント宣伝スライドのように
/// 「URL さえ分かっていれば QR は自動で作れる」ものは、画像アセットを
/// 追加せずにここで生成する。
enum QRCodeGenerator {
  private static let context = CIContext()

  /// - Parameter scale: `CIQRCodeGenerator` の出力は 1 モジュール = 1px と
  ///   非常に小さいため、そのまま表示すると補間でぼやける。整数倍に拡大してから
  ///   CGImage 化することで、輪郭がはっきりした QR になる。
  static func image(for string: String, scale: CGFloat = 12) -> CGImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage else { return nil }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    return context.createCGImage(scaled, from: scaled.extent)
  }
}
