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
      name: "DepthSlidesSlides",
      dependencies: [
        "MarkdownToSlide",
        .product(name: "SlideKit", package: "SlideKit"),
      ],
      resources: [
        .copy("Models")
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
