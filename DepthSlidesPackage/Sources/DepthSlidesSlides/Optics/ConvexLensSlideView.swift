import MarkdownToSlide
import SwiftUI

/// Interactive convex-lens ray diagram laid out for a 16:9 slide: the canvas
/// on the left, live-adjustable sliders on the right (unlike the
/// portrait-oriented, stacked layout of the original LightSimulation app).
struct ConvexLensSlideView: View {
  @Environment(\.slideTheme) var slideTheme
  @State private var scene: LensScene

  init(scene: LensScene = LensScene()) {
    _scene = State(initialValue: scene)
  }

  var body: some View {
    HStack(alignment: .top, spacing: 24) {
      VStack(alignment: .leading, spacing: 8) {
        GeometryReader { geometry in
          Canvas { context, size in
            let di = scene.imageDistance
            let minX = min(scene.objectX, di ?? scene.objectX) - 10
            let maxX = max(scene.screenX, di ?? scene.screenX) + 10
            let maxAbsHeight =
              max(scene.objectHeight, abs(scene.imageHeight ?? 0), scene.focalLength * 0.3) + 15
            let transform = RayCanvasDrawing.fitTransform(
              minX: minX, maxX: maxX, maxAbsHeight: maxAbsHeight, in: size)

            RayCanvasDrawing.drawAxis(&context, minX: minX, maxX: maxX, transform: transform)
            RayCanvasDrawing.drawScreen(
              &context, x: scene.screenX, halfExtent: maxAbsHeight, transform: transform)
            RayCanvasDrawing.drawLensShape(
              &context, x: scene.lensX, halfHeight: maxAbsHeight * 0.85, transform: transform)
            RayCanvasDrawing.drawMarker(
              &context, at: scene.farFocalPoint, transform: transform, color: .secondary)
            RayCanvasDrawing.drawMarker(
              &context, at: scene.nearFocalPoint, transform: transform, color: .secondary)

            for objectPoint in scene.objectSamplePoints {
              for segment in scene.constructionRays(for: objectPoint) {
                RayCanvasDrawing.drawRay(&context, segment: segment, transform: transform)
              }
            }

            RayCanvasDrawing.drawArrowObject(
              &context, base: CGPoint(x: scene.objectX, y: 0),
              tip: CGPoint(x: scene.objectX, y: scene.objectHeight), transform: transform)

            if let di, let hi = scene.imageHeight {
              RayCanvasDrawing.drawArrowObject(
                &context, base: CGPoint(x: di, y: 0), tip: CGPoint(x: di, y: hi),
                transform: transform, color: .orange)
              RayCanvasDrawing.drawMarker(
                &context, at: CGPoint(x: di, y: hi), transform: transform, color: .orange)
            }
          }
          .animation(.easeInOut(duration: 0.2), value: scene)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))

        statusLabel
          .font(.footnote)
          .foregroundStyle(slideTheme.secondaryTextColor)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      VStack(spacing: 16) {
        LabeledSlider(label: "焦点距離 f", value: $scene.focalLength, range: 20...100)
        LabeledSlider(label: "物体の高さ", value: $scene.objectHeight, range: 10...80)
        LabeledSlider(label: "物体 〜 レンズの距離", value: $scene.objectDistance, range: 15...220)
        LabeledSlider(label: "レンズ 〜 スクリーンの距離", value: $scene.lensToScreenDistance, range: 20...220)
      }
      .frame(width: 440)
    }
  }

  @ViewBuilder
  private var statusLabel: some View {
    if scene.isAtInfinity {
      Text("物体が焦点上にあるため、光は集まらず像は無限遠にできます")
    } else if scene.isVirtualImage, let di = scene.imageDistance {
      Text(String(format: "虚像(拡大鏡と同じ仕組み): レンズから %.0f の位置に正立の虚像", abs(di)))
    } else if let di = scene.imageDistance {
      Text(String(format: "実像: レンズから %.0f の位置に倒立の実像", di))
    }
  }
}

#Preview("標準 (2f の外側)") {
  ConvexLensSlideView()
    .padding()
}

#Preview("f 〜 2f の間") {
  ConvexLensSlideView(scene: LensScene(focalLength: 60, objectDistance: 90))
    .padding()
}

#Preview("焦点の内側 (虚像)") {
  ConvexLensSlideView(scene: LensScene(focalLength: 60, objectDistance: 30))
    .padding()
}
