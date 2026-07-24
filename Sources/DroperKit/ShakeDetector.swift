import Foundation
import CoreGraphics

/// Saf mantık: (zaman, x) örnek akışından "fare sallandı" kararı üretir.
/// Yatay yön değişimlerini sayar; kısa zaman penceresinde eşik aşılırsa shake kabul edilir.
public struct ShakeDetector {
    public enum Sensitivity: String, CaseIterable, Sendable {
        case low, medium, high

        /// Shake sayılması için pencere içinde gereken yön değişimi sayısı.
        public var requiredReversals: Int {
            switch self {
            case .low: return 6
            case .medium: return 4
            case .high: return 3
            }
        }

        /// Yön değişimlerinin sayıldığı zaman penceresi (saniye).
        /// 0.6 gerçek elde çok sıkı çıktı (manuel test 2026-07-24); 0.9'a genişletildi.
        public var window: TimeInterval { 0.9 }

        /// Bir hareketin yön olarak sayılması için gereken en küçük yatay mesafe (punto).
        public var minDelta: CGFloat { 4 }
    }

    public var sensitivity: Sensitivity

    private var lastX: CGFloat?
    private var lastDirection: Int = 0
    private var reversalTimes: [TimeInterval] = []

    public init(sensitivity: Sensitivity = .medium) {
        self.sensitivity = sensitivity
    }

    public mutating func reset() {
        lastX = nil
        lastDirection = 0
        reversalTimes.removeAll()
    }

    /// Yeni bir örnek işler; shake tespit edildiği anda `true` döner ve durum sıfırlanır.
    @discardableResult
    public mutating func addSample(time: TimeInterval, x: CGFloat) -> Bool {
        guard let last = lastX else {
            lastX = x
            return false
        }
        let dx = x - last
        guard abs(dx) >= sensitivity.minDelta else { return false }
        lastX = x
        let direction = dx > 0 ? 1 : -1
        defer { lastDirection = direction }
        guard lastDirection != 0, direction != lastDirection else { return false }

        reversalTimes.append(time)
        reversalTimes.removeAll { time - $0 > sensitivity.window }
        if reversalTimes.count >= sensitivity.requiredReversals {
            reset()
            return true
        }
        return false
    }
}
