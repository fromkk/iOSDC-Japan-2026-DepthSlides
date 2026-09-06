// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "DepthSlides",
  platforms: [
    .iOS(.v26),
    .macOS(.v26),
  ],
  products: [
    .library(
      name: "MarkdownToSlide",
      targets: ["MarkdownToSlide"]
    ),
    .library(
      name: "DepthSlidesSlides",
      targets: ["DepthSlidesSlides"]
    ),
    .library(
      name: "DinnerChimeKit",
      targets: ["DinnerChimeKit"]
    ),
    .library(
      name: "EventPRSlides",
      targets: ["EventPRSlides"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/mtj0928/SlideKit", branch: "main"),
    .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.7.3"),
  ],
  targets: [
    .target(
      name: "MarkdownToSlide",
      dependencies: [
        .product(name: "Markdown", package: "swift-markdown"),
        .product(name: "SlideKit", package: "SlideKit"),
      ]
    ),
    .target(
      name: "DinnerChimeKit"
    ),
    // 登壇の最後に出すイベント宣伝スライド。深度推定とは独立していて、
    // 宣伝だけの単体アプリ（EventPR）からも本編スライドからも使う。
    .target(
      name: "EventPRSlides",
      dependencies: [
        "MarkdownToSlide",
        .product(name: "SlideKit", package: "SlideKit"),
      ],
      resources: [
        .process("Resources")
      ]
    ),
    .target(
      name: "DepthSlidesSlides",
      dependencies: [
        "MarkdownToSlide",
        "DinnerChimeKit",
        "EventPRSlides",
        .product(name: "SlideKit", package: "SlideKit"),
      ],
      resources: [
        .copy("Models"),
        // 深度情報付き HEIC などを加工せずそのまま同梱する（xcassets 経由だと
        // AVDepthData の補助データが取り出せないため）
        .copy("DepthSamples"),
        // f値 だけを変えて撮った実写の連番（09_FNumberDemo のフェーズ2）
        .copy("ApertureSamples"),
        // 同じ場所から iPhone のレンズを切り替えて撮った連番（13_iPhonePhotoTips）
        .copy("TelephotoSamples"),
        // スライド内で再生する動画（25_ToneCraftAnnounce のアプリ操作画面など）
        .process("Resources"),
      ]
    ),
    .testTarget(
      name: "MarkdownToSlideTests",
      dependencies: [
        "MarkdownToSlide",
        .product(name: "Markdown", package: "swift-markdown"),
      ]
    ),
  ]
)
