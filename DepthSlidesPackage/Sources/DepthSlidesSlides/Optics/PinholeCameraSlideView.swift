import SwiftUI

/// Interactive pinhole-camera ray diagram laid out for a 16:9 slide: the
/// canvas on the left, live-adjustable sliders on the right (unlike the
/// portrait-oriented, stacked layout of the original LightSimulation app).
struct PinholeCameraSlideView: View {
  @State private var scene: PinholeScene

  init(scene: PinholeScene = PinholeScene()) {
    _scene = State(initialValue: scene)
  }

  var body: some View {
    HStack(alignment: .top, spacing: 24) {
      GeometryReader { geometry in
        Canvas { context, size in
          let halfExtent = scene.barrierHalfExtent * 1.15
          let transform = RayCanvasDrawing.fitTransform(
            minX: scene.objectX,
            maxX: scene.screenX,
            maxAbsHeight: halfExtent,
            in: size
          )

          RayCanvasDrawing.drawAxis(
            &context, minX: scene.objectX, maxX: scene.screenX, transform: transform)
          RayCanvasDrawing.drawScreen(
            &context, x: scene.screenX, halfExtent: halfExtent, transform: transform)
          RayCanvasDrawing.drawWallWithGap(
            &context,
            x: scene.barrierX,
            gapCenter: scene.apertureHeight,
            gapSize: scene.apertureSize,
            halfExtent: scene.barrierHalfExtent,
            transform: transform
          )

          var projectedBase = CGPoint.zero
          var projectedTip = CGPoint.zero
          for (index, objectPoint) in scene.objectSamplePoints.enumerated() {
            let (surviving, screenPoint, blocked) = scene.trace(objectPoint: objectPoint)
            for ray in blocked {
              RayCanvasDrawing.drawRay(&context, segment: ray, transform: transform)
            }
            for ray in scene.blurEdgeRays(objectPoint: objectPoint) {
              RayCanvasDrawing.drawRay(&context, segment: ray, transform: transform)
            }
            RayCanvasDrawing.drawRay(&context, segment: surviving, transform: transform)
            RayCanvasDrawing.drawMarker(
              &context, at: screenPoint, transform: transform, color: .orange)

            if index == 0 { projectedBase = screenPoint } else { projectedTip = screenPoint }
          }

          RayCanvasDrawing.drawArrowObject(
            &context, base: CGPoint(x: scene.objectX, y: 0),
            tip: CGPoint(x: scene.objectX, y: scene.objectHeight), transform: transform)
          RayCanvasDrawing.drawArrowObject(
            &context, base: projectedBase, tip: projectedTip, transform: transform, color: .orange)
        }
        .animation(.easeInOut(duration: 0.2), value: scene)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(.black.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))

      VStack(spacing: 16) {
        LabeledSlider(label: "穴の大きさ", value: $scene.apertureSize, range: 2...40)
        LabeledSlider(label: "物体の高さ", value: $scene.objectHeight, range: 10...80)
        LabeledSlider(label: "物体 〜 壁の距離", value: $scene.objectDistance, range: 40...220)
        LabeledSlider(label: "壁 〜 スクリーンの距離", value: $scene.barrierToScreenDistance, range: 40...220)
      }
      .frame(width: 440)
    }
  }
}

#Preview("標準") {
  PinholeCameraSlideView()
    .padding()
}

#Preview("小さい穴") {
  PinholeCameraSlideView(scene: PinholeScene(apertureSize: 2))
    .padding()
}

#Preview("大きい穴 (ボケる)") {
  PinholeCameraSlideView(scene: PinholeScene(apertureSize: 34))
    .padding()
}
