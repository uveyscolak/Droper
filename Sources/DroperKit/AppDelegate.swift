import AppKit
import ApplicationServices

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore.shared
    private var statusController: StatusItemController?
    private var dragMonitor: DragMonitor?
    private var settingsController: SettingsWindowController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusItemController(
            onNewShelf: {
                ShelfManager.shared.openShelf(at: NSEvent.mouseLocation)
            },
            onSettings: { [weak self] in
                self?.showSettings()
            })

        let monitor = DragMonitor(settings: settings)
        monitor.onTrigger = { point in
            ShelfManager.shared.openOrReuseShelf(at: point)
        }
        monitor.onDragEnded = {
            ShelfManager.shared.dragEnded()
        }
        monitor.start()
        dragMonitor = monitor

        promptForAccessibilityIfNeeded()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        dragMonitor?.stop()
    }

    private func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(settings: settings)
        }
        settingsController?.show()
    }

    /// Global fare izleme Accessibility izni ister; yoksa sistem izin penceresini tetikle.
    private func promptForAccessibilityIfNeeded() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let trusted = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        if !trusted {
            print("Accessibility izni bekleniyor — Sistem Ayarları > Gizlilik ve Güvenlik > Erişilebilirlik")
        }
    }
}
