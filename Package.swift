import PackageDescription

let package = Package(
    name: "sciv",
    dependencies: [
        .Package(url: "https://github.com/kylef/PathKit", Version(0, 7, 1)),
        .Package(url: "https://github.com/sciv-img/Cpcre", Version(1, 0, 0)),
    ]
)
