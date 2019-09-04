// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "LegacyGallery",
    platforms: [
        .iOS(.v9),
    ],
    products: [
        .library(name: "LegacyGallery", targets: [ "LegacyGallery" ])
    ],
    dependencies: [],
    targets: [
        .target(name: "LegacyGallery", path: "Sources"),
    ]
)
