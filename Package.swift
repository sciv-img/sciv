// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "sciv",
    products: [
        .executable(name: "sciv", targets: ["sciv"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sciv-img/Cpcre", .exact(Version(2, 0, 0))),
        .package(url: "https://github.com/sciv-img/Cwebp", .exact(Version(2, 0, 0))),
        .package(url: "https://github.com/sciv-img/OSet", .exact(Version(0, 6, 0))),
        .package(url: "https://github.com/kylef/PathKit", .exact(Version(1, 0, 0))),
    ],
    targets: [
        .target(name: "sciv", dependencies: ["OSet", "PathKit"], path: "Sources"),
    ]
)
