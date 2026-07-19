import CoreGraphics

/// `BeforeAfterImageCompareView` のズーム・パン状態。呼び出し側が保持することで、
/// 新しい画像を選んだときだけリセットし、モデルを切り替えたときは
/// 同じズーム位置を保ったまま比較できるようにする。
struct ImageZoomState: Equatable {
  var scale: CGFloat = 1
  var offset: CGSize = .zero

  static let identity = ImageZoomState()
}
