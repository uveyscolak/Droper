// swift-tools-version:6.0
import PackageDescription

// Xcode'suz (yalnız Command Line Tools) kurulumda CLT'nin hazır Testing.framework'ü
// derleyicinin makro eklentisiyle uyumsuz: testler keşfedilmiyor ve `swift test`
// hiç test koşmadan "Build complete" deyip çıkıyor — sahte yeşil. Bu yüzden
// swift-testing kaynaktan derlenir.
//
// Sürüm 6.3.1'de sabit: 6.3.2'nin makro aracı Swift 6.3.3'ün SwiftSyntax'ıyla
// linklenmiyor (Undefined symbols: SyntaxVisitor.visitationFunc). 6.3.1 hem 6.3.2
// hem 6.3.3 araç zincirinde doğrulandı — kasten bozuk test yazılıp gerçekten
// FAILED verdiği görüldü. Aralık (`from:`) kullanılmıyor: SPM en yeni tag'i seçip
// yine kırılıyor. Araç zinciri ilerlerse burası yeniden doğrulanmalı.
//
// swift-testing'in ihtiyaç duyduğu lib_TestingInterop.dylib'in CLT içindeki yeri.
let cltTestingLib = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

let package = Package(
    name: "Droper",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "6.3.1")
    ],
    targets: [
        .target(
            name: "DroperKit",
            swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(
            name: "Droper",
            dependencies: ["DroperKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(
            name: "DroperKitTests",
            dependencies: [
                "DroperKit",
                .product(name: "Testing", package: "swift-testing"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .unsafeFlags([
                    "-L", cltTestingLib,
                    "-Xlinker", "-rpath", "-Xlinker", cltTestingLib,
                ])
            ]),
    ]
)
