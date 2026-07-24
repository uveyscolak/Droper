import AppKit

/// Global sürükleme olaylarını izler; raf açtırma tetikleyicileri:
/// 1) dosya sürüklemesi ~1 sn sürünce otomatik, 2) fare sallama, 3) Shift.
/// Gerçek dosya sürüklemesi, drag pasteboard'un changeCount'u yeni bir oturuma
/// işaret ettiğinde ve içerikte dosya URL'si olduğunda kabul edilir — böylece
/// metin seçimi gibi sürüklemeler (bayat pasteboard içeriğiyle) raf açtırmaz.
/// Çalışması için Accessibility izni gerekir (README'de anlatılır).
public final class DragMonitor {
    private let settings: SettingsStore
    private var detector: ShakeDetector
    private var monitor: Any?

    private var lastChangeCount = 0
    private var fileDragActive = false
    private var dragStartTime: TimeInterval = 0
    private var triggeredForCurrentDrag = false

    /// Dosya sürüklemesi bu kadar sürünce raf kendiliğinden açılır.
    private let autoOpenDelay: TimeInterval = 1.0

    /// Raf açılması gerektiğinde ekran koordinatıyla çağrılır (main queue).
    public var onTrigger: ((NSPoint) -> Void)?
    /// Dosya sürüklemesi bittiğinde çağrılır (main queue) — terk edilen boş
    /// rafların kapatılması için.
    public var onDragEnded: (() -> Void)?

    public init(settings: SettingsStore) {
        self.settings = settings
        self.detector = ShakeDetector(sensitivity: settings.sensitivity)
    }

    public func start() {
        guard monitor == nil else { return }
        lastChangeCount = NSPasteboard(name: .drag).changeCount
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handle(event)
        }
    }

    public func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseUp:
            if fileDragActive {
                DispatchQueue.main.async { [weak self] in
                    self?.onDragEnded?()
                }
            }
            fileDragActive = false
            triggeredForCurrentDrag = false
            detector.reset()
        case .leftMouseDragged:
            let pasteboard = NSPasteboard(name: .drag)
            if pasteboard.changeCount != lastChangeCount {
                // Yeni bir sürükleme oturumu başladı.
                lastChangeCount = pasteboard.changeCount
                fileDragActive = pasteboard.canReadObject(
                    forClasses: [NSURL.self],
                    options: [.urlReadingFileURLsOnly: true])
                dragStartTime = event.timestamp
                triggeredForCurrentDrag = false
                detector.reset()
            }
            guard fileDragActive, !triggeredForCurrentDrag else { return }

            if settings.shiftTriggerEnabled, event.modifierFlags.contains(.shift) {
                trigger()
                return
            }
            if settings.autoOpenEnabled, event.timestamp - dragStartTime >= autoOpenDelay {
                trigger()
                return
            }
            if detector.sensitivity != settings.sensitivity {
                detector = ShakeDetector(sensitivity: settings.sensitivity)
            }
            if detector.addSample(time: event.timestamp, x: NSEvent.mouseLocation.x) {
                trigger()
            }
        default:
            break
        }
    }

    private func trigger() {
        triggeredForCurrentDrag = true
        let point = NSEvent.mouseLocation
        DispatchQueue.main.async { [weak self] in
            self?.onTrigger?(point)
        }
    }
}
