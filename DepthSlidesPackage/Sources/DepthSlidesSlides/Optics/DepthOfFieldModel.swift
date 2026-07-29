import CoreGraphics
import Foundation

/// Thin-lens model with a finite aperture, used to visualize depth of field:
/// the screen is fixed at the conjugate (image) distance of a chosen "focus"
/// subject. Rays leaving any object point through the top/bottom edges of the
/// aperture always converge, after refraction, at that object's own
/// conjugate image point (the thin-lens equation is exact for every ray, not
/// just the paraxial ones this simplified drawing shows). For the focus
/// subject that conjugate point *is* the screen, so both edge rays land on
/// the same point -- sharp. For any other object distance, the two edge rays,
/// extended past their own conjugate point to the fixed screen plane, land on
/// two different points -- the gap between them is the circle of confusion
/// (here, its 2D cross-section) that we call "blur".
///
/// Depth of field itself is the range of object distances whose circle of
/// confusion stays at or below `acceptableCoCDiameter`; `nearLimit`/
/// `farLimit` solve for that range's boundary directly from the same
/// geometry (no separate hyperfocal-distance approximation).
struct DepthOfFieldScene: Equatable {
    /// Kept fixed (no slider) so the demo isolates the effect of the
    /// aperture, matching the f-number narrative in `09_FNumber`.
    var focalLength: CGFloat = 60
    /// f値 = 焦点距離 / 絞りの実直径, i.e. `apertureDiameter = focalLength / fNumber`.
    var fNumber: CGFloat = 4
    /// 被写体までの距離。スクリーンはこの被写体の結像位置に固定される。
    var focusDistance: CGFloat = 150
    var objectHeight: CGFloat = 30

    /// 許容錯乱円径: この大きさ以下のボケは「シャープ」とみなす基準値。
    /// 実際のカメラでは撮像素子のサイズ等から決まるが、このデモでは
    /// スライダーの可動域全体で近点・遠点が自然な値になるよう固定値を採用している。
    let acceptableCoCDiameter: CGFloat = 2.0

    var lensX: CGFloat { 0 }

    /// 絞りの実直径 (f値 = 焦点距離 / 絞りの実直径 の定義そのまま)。
    var apertureDiameter: CGFloat { focalLength / fNumber }

    /// Thin lens equation: 1/f = 1/do + 1/di => di = f*do / (do - f).
    private func imageDistance(for objectDistance: CGFloat) -> CGFloat {
        (focalLength * objectDistance) / (objectDistance - focalLength)
    }

    /// Inverse of `imageDistance(for:)`: do = di*f / (di - f).
    private func objectDistance(forImageDistance di: CGFloat) -> CGFloat {
        di * focalLength / (di - focalLength)
    }

    /// Magnification m = -di/do; image height hi = m * ho.
    private func imageHeight(for objectDistance: CGFloat, height: CGFloat) -> CGFloat {
        let di = imageDistance(for: objectDistance)
        return -(di / objectDistance) * height
    }

    /// スクリーンは常に被写体の結像位置に固定する。
    var screenX: CGFloat { imageDistance(for: focusDistance) }

    /// 絞りの上端・下端を通る2本の光線を、その物体自身の結像点に向けて延長し、
    /// 固定されたスクリーン位置での着地点を求めた結果。
    struct EdgeRayResult {
        let preLens: [LineSegment]
        let postLens: [LineSegment]
        let topLanding: CGPoint
        let bottomLanding: CGPoint
    }

    /// - Parameters:
    ///   - objectDistance: `focusDistance` を渡せば2本の光線は同じ点に収束し
    ///     (シャープ)、それ以外の距離を渡せば異なる点に着地する (ボケ)。
    func edgeRays(objectDistance: CGFloat, objectHeight: CGFloat) -> EdgeRayResult {
        let objectPoint = CGPoint(x: -objectDistance, y: objectHeight)
        let imagePoint = CGPoint(
            x: imageDistance(for: objectDistance),
            y: imageHeight(for: objectDistance, height: objectHeight)
        )

        let halfAperture = apertureDiameter / 2
        var preLens: [LineSegment] = []
        var postLens: [LineSegment] = []
        var landings: [CGPoint] = []

        for edgeY in [halfAperture, -halfAperture] {
            let lensPoint = CGPoint(x: lensX, y: edgeY)
            preLens.append(LineSegment(start: objectPoint, end: lensPoint))

            let landing = Geometry.point(onLineThrough: lensPoint, and: imagePoint, atX: screenX)
            postLens.append(LineSegment(start: lensPoint, end: landing))
            landings.append(landing)
        }

        return EdgeRayResult(
            preLens: preLens, postLens: postLens,
            topLanding: landings[0], bottomLanding: landings[1])
    }

    /// 任意の距離にある被写体の、スクリーン上でのボケ (錯乱円) の大きさ。
    func circleOfConfusion(atDistance objectDistance: CGFloat) -> CGFloat {
        let result = edgeRays(objectDistance: objectDistance, objectHeight: objectHeight)
        return abs(result.topLanding.y - result.bottomLanding.y)
    }

    /// 錯乱円径がちょうど `acceptableCoCDiameter` になる結像距離を、
    /// スクリーンよりカメラ側(`di > screenX`, 近点)・奥側(`di < screenX`, 遠点)の
    /// 両方について求める。導出:
    /// `circleOfConfusion(d)/apertureDiameter = |1 - screenX / di(d)|` なので
    /// `k = acceptableCoCDiameter / apertureDiameter` として
    /// `di = screenX / (1 - k)`(近点側) / `di = screenX / (1 + k)`(遠点側)。
    private func boundaryImageDistance(nearSide: Bool) -> CGFloat {
        let k = acceptableCoCDiameter / apertureDiameter
        return nearSide ? screenX / (1 - k) : screenX / (1 + k)
    }

    /// 近点: 被写体距離より手前側で、錯乱円がちょうど許容値になる距離。
    var nearLimit: CGFloat {
        objectDistance(forImageDistance: boundaryImageDistance(nearSide: true))
    }

    /// 遠点: 被写体距離より奥側で、錯乱円がちょうど許容値になる距離。
    /// 過焦点距離を超えて無限遠まで合焦域が続く場合は `nil`。
    var farLimit: CGFloat? {
        let di = boundaryImageDistance(nearSide: false)
        guard di > focalLength else { return nil }
        return objectDistance(forImageDistance: di)
    }
}
