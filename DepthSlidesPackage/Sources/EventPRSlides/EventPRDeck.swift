import SlideKit

/// 宣伝スライドをモジュールの外に渡すための入り口。
///
/// `@Slide` マクロが生成するメンバーは public にできない（生成される
/// `phasesStateSore()` などが internal のままなので、public な型が
/// public プロトコル `Slide` に適合できない）。そのためスライド型そのものは
/// 公開せず、型消去した `[any Slide]` として渡す。受け取る側は
/// `SlideIndexController(slides:)` にそのまま繋げられる。
public enum EventPRDeck {
  @MainActor
  public static var slides: [any Slide] {
    // 開催が近い順に並べる
    [
      ExtensionDCPR(),
      KanagawaSwiftPR(),
      SaitamaSwiftPR(),
    ]
  }
}
