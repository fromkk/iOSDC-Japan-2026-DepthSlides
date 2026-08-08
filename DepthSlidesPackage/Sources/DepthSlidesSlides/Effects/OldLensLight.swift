import SwiftUI

/// オールドレンズ越しの光を再現するための位相計算。
/// 全レイヤーが同じ時刻から位置を算出するため、単一の光源が動いているように見える。
struct LensLightPhase {
  let time: TimeInterval

  init(date: Date) {
    self.time = date.timeIntervalSinceReferenceDate
  }

  /// 光源が画面を一周するおおよその周期(秒)
  static let orbitPeriod: TimeInterval = 26

  /// 光源位置。リサージュ軌道でゆっくり漂う(x/y の周波数比が非整数なので同じ軌跡を繰り返さない)
  func lightPoint(delay: TimeInterval = 0) -> UnitPoint {
    let u = (time - delay) * 2 * .pi / Self.orbitPeriod
    return UnitPoint(
      x: 0.5 + 0.6 * sin(u),
      y: 0.3 + 0.25 * sin(u * 0.63 + 1.3)
    )
  }

  var lightPoint: UnitPoint { lightPoint() }

  /// 光源と画面中心を挟んだ反対側(レンズゴーストが出る位置)
  var ghostPoint: UnitPoint {
    let point = lightPoint
    return UnitPoint(x: 1 - point.x, y: 1 - point.y)
  }

  /// ハレーションの呼吸(ゆっくりした明滅)。0...1
  var breathing: Double {
    0.5 + 0.5 * sin(time * 2 * .pi / 9)
  }

  /// ピントの外れ具合。0...1
  /// 大半の時間は 0(合焦)付近に張り付き、周期的にふわっとボケて戻る
  var defocus: Double {
    let wave = 0.5 + 0.5 * sin(time * 2 * .pi / 13)
    return pow(wave, 4)
  }
}

/// オールドレンズ光沢エフェクトの調整パラメータ
struct OldLensLightStyle {
  /// スペキュラハイライトの色
  var glowColor: Color = Color(red: 1.0, green: 0.92, blue: 0.78)
  /// ハイライトの広がり(pt)
  var glowRadius: CGFloat = 520
  /// 影の濃さ
  var shadowOpacity: Double = 0.3
  /// ピントが外れたときの最大ぼかし量(pt)。0 でフォーカス変化なし
  var maxDefocusBlur: CGFloat = 10

  /// タイトル向けの強めの設定
  static let title = OldLensLightStyle()

  /// サブタイトルなど控えめにしたい要素向け
  static let subtle = OldLensLightStyle(
    glowRadius: 320,
    shadowOpacity: 0.18,
    maxDefocusBlur: 6
  )
}

/// テキストなどに「動く光の反射・影・オールドレンズの滲み」を重ねるモディファイア
struct OldLensLightModifier: ViewModifier {
  var style: OldLensLightStyle

  func body(content: Content) -> some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
      let phase = LensLightPhase(date: context.date)
      let light = phase.lightPoint

      content
        // 光源の反対側へ落ちる影
        .shadow(
          color: .black.opacity(style.shadowOpacity * (0.7 + 0.3 * phase.breathing)),
          radius: 18,
          x: (0.5 - light.x) * 42,
          y: (0.5 - light.y) * 30
        )
        // 光源に追従するスペキュラハイライト + 斜めに掃く光の帯
        .overlay {
          ZStack {
            RadialGradient(
              colors: [style.glowColor.opacity(0.95), style.glowColor.opacity(0)],
              center: light,
              startRadius: 0,
              endRadius: style.glowRadius
            )
            sheen(location: min(max(light.x, 0), 1))
          }
          .mask(content)
          .blendMode(.plusLighter)
          .allowsHitTesting(false)
        }
        // レンズがピントを探すような、時々ふわっとボケて戻る動き
        .blur(radius: style.maxDefocusBlur * phase.defocus)
    }
  }

  /// ガラス面を光が掃くような斜めの帯
  private func sheen(location: Double) -> some View {
    LinearGradient(
      stops: [
        .init(color: .clear, location: 0),
        .init(color: .clear, location: max(0, location - 0.16)),
        .init(color: .white.opacity(0.55), location: location),
        .init(color: .clear, location: min(1, location + 0.16)),
        .init(color: .clear, location: 1),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}

extension View {
  /// オールドレンズ越しの光(動く反射と影)をテキストに重ねる
  func oldLensLight(_ style: OldLensLightStyle = .title) -> some View {
    modifier(OldLensLightModifier(style: style))
  }
}

/// スライド背景用の光漏れ。テキスト側のエフェクトと同じ光源位置を共有する
struct OldLensLightLeakBackground: View {
  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
      let phase = LensLightPhase(date: context.date)
      GeometryReader { geometry in
        let size = geometry.size
        let light = phase.lightPoint
        let ghost = phase.ghostPoint

        ZStack {
          // 主光源の暖色フレア
          Circle()
            .fill(Color(red: 1.0, green: 0.62, blue: 0.3))
            .frame(width: size.width * 0.5)
            .position(x: size.width * light.x, y: size.height * light.y)
            .blur(radius: 140)
            .opacity(0.14 + 0.06 * phase.breathing)

          // 対角に出るレンズゴースト
          Circle()
            .fill(Color(red: 0.45, green: 0.95, blue: 0.85))
            .frame(width: size.width * 0.12)
            .position(x: size.width * ghost.x, y: size.height * ghost.y)
            .blur(radius: 36)
            .opacity(0.08)
        }
        .clipped()
      }
      .allowsHitTesting(false)
    }
  }
}

#Preview {
  VStack(alignment: .leading, spacing: 80) {
    Text("オールドレンズの光")
      .font(.system(size: 96, weight: .bold))
      .oldLensLight()

    Text("subtle style")
      .font(.system(size: 72, weight: .bold))
      .oldLensLight(.subtle)
  }
  .padding(60)
  .frame(width: 1280, height: 720)
  .background { OldLensLightLeakBackground() }
}
