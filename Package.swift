import PackageDescription

let package = Package(
    name: "sciv",
    dependencies: [
        .Package(url: "https://github.com/kylef/PathKit", versions: Version(0, 6, 1)..<Version(0, 7, 0))
    ]
)
