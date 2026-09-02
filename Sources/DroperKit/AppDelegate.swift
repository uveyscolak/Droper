import AppKit
import ApplicationServices

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore.shared
    private var statusController: StatusItemController?
    private var dragMonitor: DragMonitor?
    private var settingsController: SettingsWindowController?
    private var permissionPollTimer: Timer?

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

    /// Global fare izleme Accessibility izni ister; yoksa sistem izin penceresini tetikler
    /// ve izin verilene kadar saniyede bir denetleyip DragMonitor'u kendiliğinden başlatır.
    private func promptForAccessibilityIfNeeded() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let trusted = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        if !trusted {
            print("Accessibility izni bekleniyor — Sistem Ayarları > Gizlilik ve Güvenlik > Erişilebilirlik")
            startPermissionPolling()
        }
    }

    /// İzin verilmemişken açılan DragMonitor'un global event tap'i sessizce boşta
    /// kalır; izin sonradan verildiğinde kendiliğinden tetiklenmez, bu yüzden
    /// izin gelene kadar bekleyip monitörü yeniden başlatıyoruz.
    private func startPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            self?.permissionPollTimer = nil
            self?.dragMonitor?.stop()
            self?.dragMonitor?.start()
            print("Accessibility izni verildi — Droper çalışmaya başladı")
        }
    }
}
