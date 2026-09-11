import SwiftUI

/// スライドヘッダーに出す「章」。
///
/// 作例スライド（`24_BeforeAfterResults`）だけが持っていたヘッダー（罫 + ラベル）を
/// 本編全体に広げるにあたって、どのスライドがどの章に属するかをここ一箇所に集める。
/// スライドを増減したらこの表だけ直せば、各スライドの `SlideHeader` は追従する。
///
/// 章に含めるのは `SlideConfiguration.mainSlides` の並び順どおり。
enum DeckSection: CaseIterable {
  case camera
  case iPhone
  case depth
  case bokeh

  var title: String {
    switch self {
    case .camera: "カメラの仕組み"
    case .iPhone: "スマホの写真"
    case .depth: "深度を得る"
    case .bokeh: "ぼかす"
    }
  }

  var slides: [DeckSlide] {
    switch self {
    case .camera:
      [
        .cameraObscuraOrigin, .aboutLens, .convexLensSimulation, .fNumber, .fNumberDemo,
        .sensorSize,
      ]
    case .iPhone:
      [.iPhonePhotoProblems, .iPhonePhotoTips, .portraitMode]
    case .depth:
      [.embeddedDepth, .modelComparison, .depthModelSimulator]
    case .bokeh:
      [.bokehBlurComparison, .bokehFilterResults]
    }
  }
}

/// 章に属する本編スライド。`DeckSection.slides` の要素。
enum DeckSlide {
  case cameraObscuraOrigin
  case aboutLens
  case convexLensSimulation
  case fNumber
  case fNumberDemo
  case sensorSize

  case iPhonePhotoProblems
  case iPhonePhotoTips
  case portraitMode

  case embeddedDepth
  case modelComparison
  case depthModelSimulator

  case bokehBlurComparison
  case bokehFilterResults

  /// 所属する章。
  var section: DeckSection {
    guard let section = DeckSection.allCases.first(where: { $0.slides.contains(self) }) else {
      // `DeckSection.slides` の表から漏れている場合だけここに来る。
      preconditionFailure("\(self) がどの DeckSection にも属していない")
    }
    return section
  }
}
