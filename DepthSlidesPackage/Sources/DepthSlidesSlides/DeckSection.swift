import SwiftUI

/// スライドヘッダーに出す「章」。
///
/// 作例スライド（`24_BeforeAfterResults`）だけが持っていたヘッダー（罫 + ラベル +
/// 現在地）を本編全体に広げるにあたって、章とその中の並び順をここ一箇所に集める。
/// スライドを増減したらこの表だけ直せば、各スライドの `SlideHeader` は追従する。
///
/// 章に含めるのは `SlideConfiguration.mainSlides` の並び順どおり。ヘッダーを描かない
/// スライド（全面画像のカメラ・オブスキュラなど）も、分母を実態に合わせるために
/// 表には載せている。
enum DeckSection: CaseIterable {
  case camera
  case iPhone
  case depth
  case bokeh

  var title: String {
    switch self {
    case .camera: "カメラの仕組み"
    case .iPhone: "iPhone の写真"
    case .depth: "深度を得る"
    case .bokeh: "ボカす"
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
      [.embeddedDepth, .modelComparison, .modelUsageNotes, .depthModelSimulator]
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
  case modelUsageNotes
  case depthModelSimulator

  case bokehBlurComparison
  case bokehFilterResults

  /// 所属する章と、その章の中での位置（1 始まり）・総数。
  var placement: (section: DeckSection, index: Int, total: Int) {
    for section in DeckSection.allCases {
      if let offset = section.slides.firstIndex(of: self) {
        return (section, offset + 1, section.slides.count)
      }
    }
    // `DeckSection.slides` の表から漏れている場合だけここに来る。
    preconditionFailure("\(self) がどの DeckSection にも属していない")
  }
}
