import Foundation

enum SlideStepDirection: Codable, Sendable {
  case forward
  case back
}

/// 端末間（Mac・iPhone等）でやり取りするプレゼンテーション同期メッセージ。
/// スライドのページ番号同期(Feature A)と、撮影中のライブプレビュー配信(Feature B)を
/// 同じコネクション上で多重化する。
enum PresentationSyncMessage: Codable, Sendable {
  /// 全端末が同時にadvertise+browseする対称設計のため、同じ相手と2本の
  /// コネクションが張られることがある(`PresentationSyncNetworkManager`参照)。
  /// `broadcast`は全接続に送るので同じイベントが2回届きうる。`senderID`+`sequence`は
  /// その重複を検出するためのもの(送信元ごとに単調増加。既に見た値以下は無視する)。
  ///
  /// `direction`がnilの場合は絶対位置への同期(新規接続時のキャッチアップ等)。
  /// `direction`がある場合は`forward()`/`back()`の相対ステップを表し、
  /// 受信側は自分の現在indexが`resultingIndex`と一致していれば同じ相対ステップを
  /// 再生してPhase(スライド内の段階表示)まで揃え、一致しなければ`resultingIndex`へ
  /// 直接move(Phaseは先頭/末尾にリセット)する。
  case slideIndex(
    senderID: UUID, sequence: Int, direction: SlideStepDirection?, resultingIndex: Int)
  case cameraPreviewFrame(jpegData: Data)

  /// 接続確立時に互いに送り合う自己紹介。`platform`は"macOS"/"iOS"のような文字列。
  /// 手動同期ボタン(`requestCurrentIndex`)で「Macを名指しで」問い合わせるために使う。
  case hello(platform: String)
  /// 手動同期用。接続先(基本的にはMac)へ「今のスライド位置を教えて」と問い合わせる。
  /// 受け取った側は`slideIndex(direction: nil, ...)`で現在地を返す。
  case requestCurrentIndex
}
