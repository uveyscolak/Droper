import Foundation

public enum SmokeTestError: Error, CustomStringConvertible {
    case check(String)
    public var description: String {
        switch self {
        case .check(let message): return "Smoke kontrolü başarısız: \(message)"
        }
    }
}

/// `droper-transfer-smoke` alt komutu: dosya işlemlerinin uçtan uca çalıştığının komut kanıtı.
/// Geçici klasörde gerçek dosyayla taşı, kopyala ve ad çakışması senaryolarını doğrular.
public enum SmokeTest {
    public static func run() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory
            .appendingPathComponent("droper-smoke-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: base) }

        let src = base.appendingPathComponent("src")
        let dst = base.appendingPathComponent("dst")
        try fm.createDirectory(at: src, withIntermediateDirectories: true)
        try fm.createDirectory(at: dst, withIntermediateDirectories: true)

        let original = src.appendingPathComponent("smoke.txt")
        try "droper smoke".write(to: original, atomically: true, encoding: .utf8)

        // 1) Taşı: kaynak silinir, hedefte belirir.
        let moved = try FileTransfer.transfer(original, toDirectory: dst, mode: .move)
        guard !fm.fileExists(atPath: original.path) else {
            throw SmokeTestError.check("taşımadan sonra kaynak hâlâ duruyor")
        }
        guard fm.fileExists(atPath: moved.path) else {
            throw SmokeTestError.check("taşınan dosya hedefte yok")
        }

        // 2) Kopyala: kaynak korunur, kopya oluşur.
        let copied = try FileTransfer.transfer(moved, toDirectory: src, mode: .copy)
        guard fm.fileExists(atPath: moved.path), fm.fileExists(atPath: copied.path) else {
            throw SmokeTestError.check("kopyalama sonrası dosyalar eksik")
        }

        // 3) Ad çakışması: üzerine yazılmaz, "smoke 2.txt" üretilir.
        let second = try FileTransfer.transfer(moved, toDirectory: src, mode: .copy)
        guard second.lastPathComponent == "smoke 2.txt" else {
            throw SmokeTestError.check(
                "çakışan ad beklenen 'smoke 2.txt' değil: \(second.lastPathComponent)")
        }

        // 4) Aynı klasöre taşıma no-op'tur.
        let noop = try FileTransfer.transfer(copied, toDirectory: src, mode: .move)
        guard noop == copied, fm.fileExists(atPath: copied.path) else {
            throw SmokeTestError.check("aynı klasöre taşıma no-op olmalıydı")
        }

        guard try String(contentsOf: moved, encoding: .utf8) == "droper smoke" else {
            throw SmokeTestError.check("dosya içeriği bozuldu")
        }
    }
}
