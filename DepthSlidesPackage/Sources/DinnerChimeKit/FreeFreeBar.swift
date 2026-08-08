import Foundation

/// 仕様書 §3 / §6.3: 両端自由の Euler–Bernoulli はりの固有モード。
/// 音板（アンダーカットのない鉄琴バー）のモーダル合成に使う。
enum FreeFreeBar {
  /// §3.1: 固有値 βₙL
  static let betaL: [Double] = [
    4.730040745, 7.853204624,
    10.995607838, 14.137165491, 17.278759657,
  ]

  /// §3.1: 周波数比 rₙ = (βₙL / β₁L)² — 非整数倍音
  static let ratios: [Double] = betaL.map { pow($0 / betaL[0], 2) }

  /// §3.2: 打点 x ∈ [0,1] でのモード形状 |Φₙ(x)| / 2（Φₙ(0) = 2 で正規化）
  static func shape(mode n: Int, at x: Double) -> Double {
    let bl = betaL[n]
    let sigma = (cosh(bl) - cos(bl)) / (sinh(bl) - sin(bl))
    let u = bl * x
    let phi = cosh(u) + cos(u) - sigma * (sinh(u) + sin(u))
    return abs(phi) / 2
  }
}
