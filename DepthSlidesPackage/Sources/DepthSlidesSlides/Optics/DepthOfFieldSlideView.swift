import MarkdownToSlide
import SwiftUI

/// Interactive depth-of-field ray diagram laid out for a 16:9 slide, mirroring
/// `ConvexLensSlideView`/`PinholeCameraSlideView`: the canvas on the left,
/// live-adjustable sliders on the right. The screen is fixed at the subject's
/// image distance (sharp point, drawn in orange); the near/far limits where
/// the circle of confusion reaches `acceptableCoCDiameter` are drawn as a
/// highlighted band along the optical axis -- depth of field as a literal
/// span of acceptably-sharp subject distances, the main thing this slide is
/// meant to demonstrate as `fNumber` changes.
///
/// Unlike the other two optics slides (object on the left, screen on the
/// right), this one draws the subject on the right and the lens/screen on
/// the left -- requested so the camera side reads as the photographer's
/// viewpoint. Only the drawing in this view is mirrored (see `mirror(_:)`
/// inside the `Canvas`); `DepthOfFieldScene`'s underlying physics keeps the
/// same object-negative/screen-positive convention as `LensScene`.
struct DepthOfFieldSlideView: View {
    @Environment(\.slideTheme) var slideTheme
    @State private var scene: DepthOfFieldScene

    /// 遠点が無限遠 (nil) の場合に、帯・軸をどこまで描画するかの上限。
    private static let displayFarCap: CGFloat = 500

    init(scene: DepthOfFieldScene = DepthOfFieldScene()) {
        _scene = State(initialValue: scene)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geometry in
                    Canvas { context, size in
                        let focusResult = scene.edgeRays(
                            objectDistance: scene.focusDistance, objectHeight: scene.objectHeight)
                        let nearLimit = scene.nearLimit
                        let farLimit = scene.farLimit
                        let farForLayout = min(farLimit ?? Self.displayFarCap, Self.displayFarCap)

                        // DepthOfFieldScene 自体は 07/08 と同じ「物体は負のX・スクリーンは
                        // 正のX」で計算する(物理モデルとしての正しさ・独立性を保つ)。
                        // このデモだけ「被写体を右、レンズ・スクリーンを左」で見せたいという
                        // 要望のため、描画時にだけXの符号を反転してミラーする。
                        func mirror(_ p: CGPoint) -> CGPoint { CGPoint(x: -p.x, y: p.y) }
                        func mirrored(_ segment: LineSegment) -> LineSegment {
                            LineSegment(start: mirror(segment.start), end: mirror(segment.end), style: segment.style)
                        }

                        let minX = -(scene.screenX + 10)
                        let maxX = farForLayout + 10
                        let maxAbsHeight = max(scene.objectHeight, scene.apertureDiameter) + 15
                        let transform = RayCanvasDrawing.fitTransform(
                            minX: minX, maxX: maxX, maxAbsHeight: maxAbsHeight, in: size)

                        RayCanvasDrawing.drawAxis(&context, minX: minX, maxX: maxX, transform: transform)
                        RayCanvasDrawing.drawScreen(
                            &context, x: -scene.screenX, halfExtent: maxAbsHeight, transform: transform)
                        RayCanvasDrawing.drawLensShape(
                            &context, x: -scene.lensX, halfHeight: maxAbsHeight * 0.85, transform: transform)

                        // 被写体: 絞りの端2本の光線は screenX で必ず同じ点に収束する。
                        // 07/08 と同じ配色にする: 被写体(物体)は primary、
                        // スクリーン上にできる像(結果)だけを orange にする。
                        for segment in focusResult.preLens + focusResult.postLens {
                            RayCanvasDrawing.drawRay(&context, segment: mirrored(segment), transform: transform)
                        }
                        RayCanvasDrawing.drawArrowObject(
                            &context,
                            base: mirror(CGPoint(x: -scene.focusDistance, y: 0)),
                            tip: mirror(CGPoint(x: -scene.focusDistance, y: scene.objectHeight)),
                            transform: transform)
                        RayCanvasDrawing.drawMarker(
                            &context, at: mirror(focusResult.topLanding), transform: transform, color: .orange)

                        // 被写界深度: 近点(手前)〜遠点(奥)で錯乱円が許容値になる範囲を、
                        // 光軸に沿った帯として描く。f値を変えるとこの帯の幅が変わる。
                        let bandHalfHeight: CGFloat = 6
                        let nearModelX = -nearLimit
                        let farModelX = -farForLayout

                        var bandPath = Path()
                        bandPath.addLines(
                            [
                                CGPoint(x: nearModelX, y: bandHalfHeight),
                                CGPoint(x: farModelX, y: bandHalfHeight),
                                CGPoint(x: farModelX, y: -bandHalfHeight),
                                CGPoint(x: nearModelX, y: -bandHalfHeight),
                            ].map { transform.point(mirror($0)) })
                        bandPath.closeSubpath()
                        context.fill(bandPath, with: .color(.green.opacity(0.18)))

                        for boundaryX in [nearModelX, farModelX] {
                            var tick = Path()
                            tick.move(to: transform.point(mirror(CGPoint(x: boundaryX, y: bandHalfHeight))))
                            tick.addLine(to: transform.point(mirror(CGPoint(x: boundaryX, y: -bandHalfHeight))))
                            context.stroke(tick, with: .color(.green), lineWidth: 2)
                        }

                        let labelY = -bandHalfHeight - 10
                        context.draw(
                            Text(String(format: "近点 %.0f", nearLimit)).font(.system(size: 18)).foregroundStyle(
                                .green),
                            at: transform.point(mirror(CGPoint(x: nearModelX, y: labelY))))
                        context.draw(
                            Text(farLimit.map { String(format: "遠点 %.0f", $0) } ?? "遠点 → 無限遠")
                                .font(.system(size: 18)).foregroundStyle(.green),
                            at: transform.point(mirror(CGPoint(x: farModelX, y: labelY))))
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
                LabeledSlider(
                    label: "f値", value: $scene.fNumber, range: 1.4...16,
                    format: { String(format: "f/%.1f", $0) })
                LabeledSlider(
                    label: "被写体までの距離", value: $scene.focusDistance,
                    range: (scene.focalLength * 1.3)...250)
            }
            .frame(width: 440)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        if let farLimit = scene.farLimit {
            Text(
                String(
                    format: "絞り実直径: %.1f / 被写界深度: %.0f 〜 %.0f (幅 %.0f)",
                    scene.apertureDiameter, scene.nearLimit, farLimit, farLimit - scene.nearLimit))
        } else {
            Text(
                String(
                    format: "絞り実直径: %.1f / 被写界深度: %.0f 〜 無限遠",
                    scene.apertureDiameter, scene.nearLimit))
        }
    }
}

#Preview("標準") {
    DepthOfFieldSlideView()
        .padding()
}

#Preview("開放 (小さいf値・被写界深度が浅い)") {
    DepthOfFieldSlideView(scene: DepthOfFieldScene(fNumber: 1.4))
        .padding()
}

#Preview("絞り込み (大きいf値・被写界深度が深い)") {
    DepthOfFieldSlideView(scene: DepthOfFieldScene(fNumber: 16))
        .padding()
}
