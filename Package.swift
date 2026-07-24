// swift-tools-version:6.0
import Foundation
import PackageDescription

// ── Test altyapısı notu ──────────────────────────────────────────────────────
// Xcode'suz (yalnız Command Line Tools) kurulumda CLT'nin hazır Testing.framework'ü
// derleyicinin makro eklentisiyle uyumsuz: testler keşfedilmiyor ve `swift test`
// hiç test koşmadan "Build complete" deyip çıkıyor — sahte yeşil. Bu yüzden
// swift-testing kaynaktan derlenir.
//
// Sürüm 6.3.1'de sabit: 6.3.2'nin makro aracı Swift 6.3.3'ün SwiftSyntax'ıyla
// linklenmiyor (Undefined symbols: SyntaxVisitor.visitationFunc). 6.3.1 hem 6.3.2
// hem 6.3.3 araç zincirinde doğrulandı — kasten bozuk test yazılıp gerçekten
// FAILED verdiği görüldü. Araç zinciri ilerlerse burası yeniden doğrulanmalı.
//
// ── Dağıtım modu (DROPER_DIST=1) ─────────────────────────────────────────────
// `swift build`, yalnız uygulama derlense bile test bağımlılıklarını da fetch
// ediyor (swift-testing + swift-syntax, taze makinede ~90 sn indirme — ölçüldü).
// Kurulum script'leri DROPER_DIST=1 ile derler: test hedefi ve bağımlılık hiç
// tanımlanmaz → son kullanıcı hiçbir paket indirmez, gömülü kaynak internetsiz
// derlenir. Geliştirme/test için değişkeni ayarlamadan çalışın.

let dagitimDerlemesi = ProcessInfo.processInfo.environment["DROPER_DIST"] != nil

// swift-testing'in ihtiyaç duyduğu lib_TestingInterop.dylib'in CLT içindeki yeri.
let cltTestingLib = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

var dependencies: [Package.Dependency] = []
var targets: [Target] = [
    .target(
        name: "DroperKit",
        swiftSettings: [.swiftLanguageMode(.v5)]),
    .executableTarget(
        name: "Droper",
        dependencies: ["DroperKit"],
        swiftSettings: [.swiftLanguageMode(.v5)]),
]

if !dagitimDerlemesi {
    dependencies.append(
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "6.3.1"))
    targets.append(
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
            ]))
}

let package = Package(
    name: "Droper",
    platforms: [.macOS(.v13)],
    dependencies: dependencies,
    targets: targets
)
