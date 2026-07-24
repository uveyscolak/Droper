import Testing
import CoreGraphics

@testable import DroperKit

struct ShakeDetectorTests {
    /// Verilen (t, x) dizisini besler; herhangi bir örnekte shake çıktıysa true döner.
    private func feed(_ samples: [(Double, CGFloat)], into detector: inout ShakeDetector) -> Bool {
        for (t, x) in samples where detector.addSample(time: t, x: x) {
            return true
        }
        return false
    }

    /// 0.05 sn aralıklarla ±genlik zigzag örnekleri üretir.
    private func zigzag(count: Int, amplitude: CGFloat, step: Double = 0.05) -> [(Double, CGFloat)] {
        (0..<count).map { i in (Double(i) * step, i % 2 == 0 ? 0 : amplitude) }
    }

    @Test func rapidZigzagIsDetectedAsShake() {
        var detector = ShakeDetector(sensitivity: .medium)
        #expect(feed(zigzag(count: 12, amplitude: 40), into: &detector))
    }

    @Test func straightDragIsNotShake() {
        var detector = ShakeDetector(sensitivity: .high)
        let samples = (0..<40).map { i in (Double(i) * 0.05, CGFloat(i) * 20) }
        #expect(!feed(samples, into: &detector))
    }

    @Test func slowOscillationIsNotShake() {
        // Yön değişimleri 0.5 sn arayla gelir: 0.9 sn'lik pencereye en fazla 2 sığar,
        // en hassas kademede bile (3 gerekir) shake sayılmamalı.
        var detector = ShakeDetector(sensitivity: .high)
        let samples = zigzag(count: 20, amplitude: 40, step: 0.5)
        #expect(!feed(samples, into: &detector))
    }

    @Test func microJitterIsNotShake() {
        // minDelta altındaki titremeler yön olarak sayılmaz.
        var detector = ShakeDetector(sensitivity: .high)
        let samples = zigzag(count: 40, amplitude: 2)
        #expect(!feed(samples, into: &detector))
    }

    @Test func sensitivityChangesThreshold() {
        // Tam 3 yön değişimi üreten kısa dizi: x = 0, 40, 0, 40, 0
        let short = zigzag(count: 5, amplitude: 40)

        var high = ShakeDetector(sensitivity: .high)
        #expect(feed(short, into: &high), "3 yön değişimi yüksek hassasiyette shake olmalı")

        var medium = ShakeDetector(sensitivity: .medium)
        #expect(!feed(short, into: &medium), "3 yön değişimi orta hassasiyete yetmemeli")

        // 4 yön değişimi: orta algılar, düşük algılamaz.
        let longer = zigzag(count: 6, amplitude: 40)
        var medium2 = ShakeDetector(sensitivity: .medium)
        #expect(feed(longer, into: &medium2))

        var low = ShakeDetector(sensitivity: .low)
        #expect(!feed(longer, into: &low))
    }

    @Test func detectorResetsAfterDetection() {
        var detector = ShakeDetector(sensitivity: .high)
        #expect(feed(zigzag(count: 8, amplitude: 40), into: &detector))
        // Tespitten sonra tek bir yön değişimi hemen yeni shake üretmemeli.
        let first = detector.addSample(time: 10.0, x: 0)
        let second = detector.addSample(time: 10.05, x: 40)
        let third = detector.addSample(time: 10.10, x: 0)
        #expect(!first)
        #expect(!second)
        #expect(!third)
    }
}
