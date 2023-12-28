// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "sciv",
    products: [
        .executable(name: "sciv", targets: ["sciv"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sciv-img/OSet", .exact(Version(0, 6, 1))),
        .package(url: "https://github.com/kylef/PathKit", .exact(Version(1, 0, 1))),
    ],
    targets: [
        .systemLibrary(
            name: "Cwebp",
            pkgConfig: "libwebp",
            providers: [.brew(["webp"])]
        ),
        .systemLibrary(
            name: "Cpcre",
            pkgConfig: "libpcre",
            providers: [.brew(["pcre"])]
        ),
        .target(name: "sciv", dependencies: ["Cpcre", "Cwebp", "OSet", "PathKit"], path: "Sources"),
    ]
)
