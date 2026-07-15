import CoreGraphics
import Foundation

/// How a ray segment should be rendered: whether it reaches its target, is
/// absorbed along the way, or is a backward extension used to locate a
/// virtual image.
enum RayStyle {
    case active
    case blocked
    case virtualExtension
}

/// A drawable segment of a light ray in model space (Y-up, arbitrary units).
struct LineSegment: Identifiable, Equatable {
    let id = UUID()
    var start: CGPoint
    var end: CGPoint
    var style: RayStyle = .active

    static func == (lhs: LineSegment, rhs: LineSegment) -> Bool {
        lhs.start == rhs.start && lhs.end == rhs.end && lhs.style == rhs.style
    }
}

extension RayStyle: Equatable {}

enum Geometry {
    /// The point on the (infinite) line through `p0` and `p1` whose X
    /// coordinate is `targetX`. Both models lay their object/aperture-or-lens/
    /// screen planes out as vertical lines along X, so every ray-continuation
    /// computation reduces to this single helper.
    static func point(onLineThrough p0: CGPoint, and p1: CGPoint, atX targetX: CGFloat) -> CGPoint {
        let dx = p1.x - p0.x
        guard abs(dx) > .ulpOfOne else { return CGPoint(x: targetX, y: p0.y) }
        let t = (targetX - p0.x) / dx
        let y = p0.y + t * (p1.y - p0.y)
        return CGPoint(x: targetX, y: y)
    }
}
