import CoreGraphics
import Foundation

/// Thin-lens model: a converging lens sits at x=0, the object stands upright
/// on the optical axis at x=-objectDistance, and the standard thin lens
/// equation locates the image. Three canonical construction rays per object
/// point are provided for drawing; all three are guaranteed by the lens
/// equation to meet at the same image point.
struct LensScene: Equatable {
  var focalLength: CGFloat = 60
  var objectDistance: CGFloat = 140
  var objectHeight: CGFloat = 40
  var lensToScreenDistance: CGFloat = 120

  private static let epsilon: CGFloat = 0.5

  var lensX: CGFloat { 0 }
  var objectX: CGFloat { -objectDistance }
  var screenX: CGFloat { lensToScreenDistance }

  var farFocalPoint: CGPoint { CGPoint(x: focalLength, y: 0) }
  var nearFocalPoint: CGPoint { CGPoint(x: -focalLength, y: 0) }

  /// True when the object sits (almost) exactly at the focal point: the
  /// thin lens equation is singular here and the image forms at infinity.
  var isAtInfinity: Bool { abs(objectDistance - focalLength) < Self.epsilon }

  /// Thin lens equation: 1/f = 1/do + 1/di => di = f*do / (do - f).
  /// Negative when the object is inside the focal length (virtual image).
  var imageDistance: CGFloat? {
    guard !isAtInfinity else { return nil }
    return (focalLength * objectDistance) / (objectDistance - focalLength)
  }

  /// Magnification m = -di/do; image height hi = m * ho.
  var imageHeight: CGFloat? {
    guard let di = imageDistance else { return nil }
    return -(di / objectDistance) * objectHeight
  }

  var imagePoint: CGPoint? {
    guard let di = imageDistance, let hi = imageHeight else { return nil }
    return CGPoint(x: di, y: hi)
  }

  /// Object inside the focal length: the lens can no longer form a real,
  /// convergent image -- di is negative (same side as the object).
  var isVirtualImage: Bool { objectDistance < focalLength }

  /// Sample points along the object (an upright arrow on the axis): its
  /// base and its tip.
  var objectSamplePoints: [CGPoint] {
    [CGPoint(x: objectX, y: 0), CGPoint(x: objectX, y: objectHeight)]
  }

  /// For one object point, the lines the 3 canonical construction rays
  /// follow after the lens plane, each given as (where it crosses the lens,
  /// another point on its post-lens line):
  /// 1. Parallel ray: crosses the lens at the object's height, then bends
  ///    through the far focal point.
  /// 2. Center ray: passes straight through the lens center undeviated
  ///    (the line is simply object -> center, extended).
  /// 3. Focal ray: aimed at the near focal point on the way in, then
  ///    emerges parallel to the axis. Skipped when the object sits at the
  ///    focal point, where this particular construction is degenerate.
  private func postLensLines(for objectPoint: CGPoint) -> [(
    lensPoint: CGPoint, throughPoint: CGPoint
  )] {
    let parallelLensPoint = CGPoint(x: 0, y: objectPoint.y)
    var lines: [(CGPoint, CGPoint)] = [
      (parallelLensPoint, farFocalPoint),
      (CGPoint(x: 0, y: 0), objectPoint),
    ]

    if !isAtInfinity {
      let focalLensPoint = Geometry.point(onLineThrough: objectPoint, and: nearFocalPoint, atX: 0)
      lines.append((focalLensPoint, CGPoint(x: focalLensPoint.x + 1, y: focalLensPoint.y)))
    }
    return lines
  }

  /// Full drawable segments for the construction rays through one object
  /// point: the incoming ray to the lens, the outgoing ray to the screen
  /// (real, solid -- transmitted light always continues forward even when
  /// diverging), and, only when the image is virtual, a dashed backward
  /// extension locating the virtual image.
  func constructionRays(for objectPoint: CGPoint) -> [LineSegment] {
    var segments: [LineSegment] = []
    for (lensPoint, throughPoint) in postLensLines(for: objectPoint) {
      segments.append(LineSegment(start: objectPoint, end: lensPoint, style: .active))

      let screenPoint = Geometry.point(onLineThrough: lensPoint, and: throughPoint, atX: screenX)
      segments.append(LineSegment(start: lensPoint, end: screenPoint, style: .active))

      if isVirtualImage, let di = imageDistance {
        let virtualPoint = Geometry.point(onLineThrough: lensPoint, and: throughPoint, atX: di)
        segments.append(LineSegment(start: lensPoint, end: virtualPoint, style: .virtualExtension))
      }
    }
    return segments
  }
}
