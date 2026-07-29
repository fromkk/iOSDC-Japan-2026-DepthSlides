import SwiftUI

/// Shared drawing helpers for the optics-bench `Canvas` views. Everything
/// here just draws already-computed model geometry -- no ray-tracing math
/// lives in this file.
enum RayCanvasDrawing {
    /// Maps model space (Y-up, arbitrary units, origin on the optical axis)
    /// into canvas space (Y-down, points).
    struct Transform {
        var scale: CGFloat
        var originX: CGFloat
        var midY: CGFloat

        func point(_ p: CGPoint) -> CGPoint {
            CGPoint(x: originX + p.x * scale, y: midY - p.y * scale)
        }
    }

    /// Computes a transform that fits the scene's model-space extent into
    /// the given canvas size with a margin, preserving aspect ratio.
    static func fitTransform(minX: CGFloat, maxX: CGFloat, maxAbsHeight: CGFloat, in size: CGSize, margin: CGFloat = 28) -> Transform {
        let usableWidth = max(size.width - margin * 2, 1)
        let usableHeight = max(size.height - margin * 2, 1)
        let spanX = max(maxX - minX, 1)
        let spanY = max(maxAbsHeight * 2, 1)
        let scale = min(usableWidth / spanX, usableHeight / spanY)
        return Transform(scale: scale, originX: margin - minX * scale, midY: size.height / 2)
    }

    static func drawAxis(_ context: inout GraphicsContext, minX: CGFloat, maxX: CGFloat, transform: Transform) {
        var path = Path()
        path.move(to: transform.point(CGPoint(x: minX, y: 0)))
        path.addLine(to: transform.point(CGPoint(x: maxX, y: 0)))
        context.stroke(path, with: .color(.secondary.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
    }

    static func drawArrowObject(_ context: inout GraphicsContext, base: CGPoint, tip: CGPoint, transform: Transform, color: Color = .primary) {
        let b = transform.point(base)
        let t = transform.point(tip)
        var shaft = Path()
        shaft.move(to: b)
        shaft.addLine(to: t)
        context.stroke(shaft, with: .color(color), lineWidth: 2.5)

        let angle = atan2(t.y - b.y, t.x - b.x)
        let headLength: CGFloat = 10
        let headAngle: CGFloat = .pi / 7
        let left = CGPoint(x: t.x - headLength * cos(angle - headAngle), y: t.y - headLength * sin(angle - headAngle))
        let right = CGPoint(x: t.x - headLength * cos(angle + headAngle), y: t.y - headLength * sin(angle + headAngle))
        var head = Path()
        head.move(to: t)
        head.addLine(to: left)
        head.move(to: t)
        head.addLine(to: right)
        context.stroke(head, with: .color(color), lineWidth: 2.5)
    }

    static func style(for segment: LineSegment) -> (color: Color, strokeStyle: StrokeStyle) {
        switch segment.style {
        case .active:
            return (.yellow, StrokeStyle(lineWidth: 1.5))
        case .blocked:
            return (.secondary.opacity(0.35), StrokeStyle(lineWidth: 1, dash: [3, 3]))
        case .virtualExtension:
            return (.yellow.opacity(0.55), StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
        }
    }

    static func drawRay(
        _ context: inout GraphicsContext, segment: LineSegment, transform: Transform,
        colorOverride: Color? = nil
    ) {
        var path = Path()
        path.move(to: transform.point(segment.start))
        path.addLine(to: transform.point(segment.end))
        let (color, strokeStyle) = style(for: segment)
        context.stroke(path, with: .color(colorOverride ?? color), style: strokeStyle)
    }

    /// A vertical barrier with a gap centered at `gapCenter` of width
    /// `gapSize`, spanning `-halfExtent...halfExtent`.
    static func drawWallWithGap(_ context: inout GraphicsContext, x: CGFloat, gapCenter: CGFloat, gapSize: CGFloat, halfExtent: CGFloat, transform: Transform) {
        let gapTop = gapCenter + gapSize / 2
        let gapBottom = gapCenter - gapSize / 2

        var upper = Path()
        upper.move(to: transform.point(CGPoint(x: x, y: halfExtent)))
        upper.addLine(to: transform.point(CGPoint(x: x, y: gapTop)))

        var lower = Path()
        lower.move(to: transform.point(CGPoint(x: x, y: gapBottom)))
        lower.addLine(to: transform.point(CGPoint(x: x, y: -halfExtent)))

        context.stroke(upper, with: .color(.primary), lineWidth: 5)
        context.stroke(lower, with: .color(.primary), lineWidth: 5)
    }

    /// A biconvex lens outline, drawn as two bulging curves meeting at top
    /// and bottom, spanning `-halfHeight...halfHeight` centered at `x`.
    static func drawLensShape(_ context: inout GraphicsContext, x: CGFloat, halfHeight: CGFloat, transform: Transform) {
        let top = transform.point(CGPoint(x: x, y: halfHeight))
        let bottom = transform.point(CGPoint(x: x, y: -halfHeight))
        let bulge = max(halfHeight * transform.scale * 0.28, 10)

        var path = Path()
        path.move(to: top)
        path.addQuadCurve(to: bottom, control: CGPoint(x: top.x + bulge, y: (top.y + bottom.y) / 2))
        path.addQuadCurve(to: top, control: CGPoint(x: top.x - bulge, y: (top.y + bottom.y) / 2))
        context.stroke(path, with: .color(.cyan), lineWidth: 2)

        var axis = Path()
        axis.move(to: top)
        axis.addLine(to: bottom)
        context.stroke(axis, with: .color(.cyan.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
    }

    static func drawScreen(_ context: inout GraphicsContext, x: CGFloat, halfExtent: CGFloat, transform: Transform) {
        var path = Path()
        path.move(to: transform.point(CGPoint(x: x, y: halfExtent)))
        path.addLine(to: transform.point(CGPoint(x: x, y: -halfExtent)))
        context.stroke(path, with: .color(.primary.opacity(0.7)), lineWidth: 4)
    }

    static func drawMarker(_ context: inout GraphicsContext, at point: CGPoint, transform: Transform, color: Color, radius: CGFloat = 3) {
        let p = transform.point(point)
        let rect = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }
}
