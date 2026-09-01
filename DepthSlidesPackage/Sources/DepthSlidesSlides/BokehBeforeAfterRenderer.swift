import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// まとめ前の Before/After 比較スライド用に、スライド本編と**同じパイプライン**
/// （Depth Anything V3 で深度推定 → `CIBokehBlur` を深度マスクで合成）を
/// 事前に走らせて after 画像を書き出すためのオフライン処理。
///
/// 本番のスライド上で推論を走らせるとモデルのロードに時間がかかり、失敗した
/// ときのリカバリーも効かないため、書き出した PNG を xcassets に入れて
/// 静止画として並べる方針にしている（`scripts/render_bokeh_before_after.sh`）。
public enum BokehBeforeAfterRenderer {
  public enum RenderError: Error, CustomStringConvertible {
    case noInputImages(URL)
    case imageLoadFailed(URL)
    case blurFailed(URL)
    case writeFailed(URL)

    public var description: String {
      switch self {
      case .noInputImages(let url): "画像が見つかりません: \(url.path)"
      case .imageLoadFailed(let url): "画像の読み込みに失敗: \(url.lastPathComponent)"
      case .blurFailed(let url): "ボケの適用に失敗: \(url.lastPathComponent)"
      case .writeFailed(let url): "書き出しに失敗: \(url.path)"
      }
    }
  }

  /// スライドで採用したモデル・フィルター。`22_Summary` の記述と揃えること。
  static let model: DepthModel = .depthAnythingV3Small
  static let filter: BokehFilterKind = .bokehBlur

  /// 書き出す画像の長辺ピクセル数。スライドでは2枚並べて表示するだけなので、
  /// 元画像のフル解像度は不要（アプリのバンドルサイズも抑えたい）。
  static let outputPixelSize = 1600
  /// `outputPixelSize` に対するボケ半径。
  static let blurRadius: CGFloat = 28

  /// `inputDirectory` 内の画像それぞれについて、`<name>_before.png` /
  /// `<name>_after.png` を `outputDirectory` に書き出す。
  /// 進捗は標準エラー出力に `[BokehRender] ...` 形式で流す。
  public static func render(inputDirectory: URL, outputDirectory: URL) async throws {
    let inputs = try imageURLs(in: inputDirectory)
    guard !inputs.isEmpty else { throw RenderError.noInputImages(inputDirectory) }

    try FileManager.default.createDirectory(
      at: outputDirectory, withIntermediateDirectories: true)

    for (index, input) in inputs.enumerated() {
      log("\(index + 1)/\(inputs.count) \(input.lastPathComponent)")
      guard
        let data = try? Data(contentsOf: input),
        let original = DepthSampleAssets.cgImage(from: data, maxPixelSize: outputPixelSize)
      else { throw RenderError.imageLoadFailed(input) }

      // 深度は「写真に埋め込まれていればそれを使い、無ければモデルで推定する」。
      // ポートレートモードで撮った写真をそのまま渡せるようにするための分岐で、
      // スライドの説明（埋め込み深度 → モデル推定の順に紹介する）とも揃う。
      let depth: CGImage
      if let embedded = try? EmbeddedDepthExtractor.extractDepthImage(from: data) {
        log("  埋め込みの AVDepthData を使用")
        depth = embedded
      } else {
        log("  \(model.displayName) で深度を推定中...")
        depth = try await DepthEstimator.shared.estimate(cgImage: original, model: model)
      }

      var parameters = BokehFilterParameters()
      parameters.radius = blurRadius
      guard
        let after = CIFilterBokehBlur.apply(
          original: original, depth: depth, filter: filter, parameters: parameters)
      else { throw RenderError.blurFailed(input) }

      let base = input.deletingPathExtension().lastPathComponent
      try write(original, to: outputDirectory.appendingPathComponent("\(base)_before.png"))
      try write(after, to: outputDirectory.appendingPathComponent("\(base)_after.png"))
    }

    log("完了: \(outputDirectory.path)")
  }

  private static func imageURLs(in directory: URL) throws -> [URL] {
    let extensions: Set<String> = ["jpg", "jpeg", "heic", "heif", "png"]
    let contents = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil)
    return
      contents
      .filter { extensions.contains($0.pathExtension.lowercased()) }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  private static func write(_ image: CGImage, to url: URL) throws {
    guard
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw RenderError.writeFailed(url) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw RenderError.writeFailed(url) }
    log("  -> \(url.lastPathComponent)")
  }

  private static func log(_ message: String) {
    FileHandle.standardError.write(Data("[BokehRender] \(message)\n".utf8))
  }
}
