import CoreGraphics
import Foundation

/// Geometric (ray-optics) model of a pinhole camera: an object emits light in
/// every direction, a barrier blocks all of it except the single ray from
/// each object point that happens to pass through the aperture, and that ray
/// continues in a straight line to the screen -- producing an inverted image.
struct PinholeScene: Equatable {
  var objectDistance: CGFloat = 120
  var barrierToScreenDistance: CGFloat = 120
  var objectHeight: CGFloat = 40
  var apertureHeight: CGFloat = 0
  var apertureSize: CGFloat = 4

  var objectX: CGFloat { 0 }
  var barrierX: CGFloat { objectDistance }
  var screenX: CGFloat { objectDistance + barrierToScreenDistance }

  /// Half-height of the drawn barrier, sized to comfortably contain the
  /// object, the aperture, and the fan of blocked rays.
  var barrierHalfExtent: CGFloat { max(objectHeight, abs(apertureHeight)) + 60 }

  /// Sample points along the object (an upright arrow standing on the
  /// optical axis): its base and its tip. Tracing both shows the
  /// top-to-bottom inversion on the screen.
  var objectSamplePoints: [CGPoint] {
    [CGPoint(x: objectX, y: 0), CGPoint(x: objectX, y: objectHeight)]
  }

  /// Where a ray from `objectPoint`, passing through the aperture at height
  /// `apertureY`, lands on the screen. Extending the same straight line
  /// from object through aperture to the screen plane *is* the
  /// similar-triangles projection -- inversion falls out for free because
  /// the line necessarily crosses the axis at the aperture.
  func projectedScreenPoint(for objectPoint: CGPoint, apertureY: CGFloat) -> CGPoint {
    Geometry.point(
      onLineThrough: objectPoint, and: CGPoint(x: barrierX, y: apertureY), atX: screenX)
  }

  /// Closed-form equivalent of `projectedScreenPoint` for the aperture
  /// center, useful for documentation and unit tests.
  func projectedHeight(objectHeight h: CGFloat) -> CGFloat {
    apertureHeight - (h - apertureHeight) * (barrierToScreenDistance / objectDistance)
  }

  /// The surviving ray (object straight through the aperture to the
  /// screen) plus a fan of rays absorbed by the barrier, for one object
  /// point.
  func trace(objectPoint: CGPoint) -> (
    surviving: LineSegment, screenPoint: CGPoint, blocked: [LineSegment]
  ) {
    let screenPoint = projectedScreenPoint(for: objectPoint, apertureY: apertureHeight)
    let surviving = LineSegment(start: objectPoint, end: screenPoint, style: .active)

    let gapEdge = apertureSize / 2
    let blockedTargets: [CGFloat] = [
      barrierHalfExtent,
      apertureHeight + gapEdge + 14,
      apertureHeight - gapEdge - 14,
      -barrierHalfExtent,
    ]
    let blocked = blockedTargets.map {
      LineSegment(start: objectPoint, end: CGPoint(x: barrierX, y: $0), style: .blocked)
    }
    return (surviving, screenPoint, blocked)
  }

  /// Rays through the top/bottom edge of the aperture rather than its
  /// center: the spread between where they land on the screen visualizes
  /// the blur/penumbra a wider aperture produces.
  func blurEdgeRays(objectPoint: CGPoint) -> [LineSegment] {
    let gapEdge = apertureSize / 2
    return [apertureHeight - gapEdge, apertureHeight + gapEdge].map { edgeY in
      LineSegment(
        start: objectPoint, end: projectedScreenPoint(for: objectPoint, apertureY: edgeY),
        style: .active)
    }
  }
}
