import AppKit
import ServiceManagement

/// Basit ayarlar penceresi: hassasiyet, taşı/kopyala, Shift tetikleyici, girişte başlat.
public final class SettingsWindowController: NSWindowController {
    private let settings: SettingsStore

    private let sensitivityPopup = NSPopUpButton()
    private let modePopup = NSPopUpButton()
    private let autoOpenCheckbox = NSButton(
        checkboxWithTitle: "Sürükleyince rafı otomatik aç (1 sn)", target: nil, action: nil)
    private let shiftCheckbox = NSButton(
        checkboxWithTitle: "Sürüklerken Shift ile de raf aç", target: nil, action: nil)
    private let loginCheckbox = NSButton(
        checkboxWithTitle: "Oturum açılınca başlat", target: nil, action: nil)

    public init(settings: SettingsStore) {
        self.settings = settings
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false)
        window.title = "Droper Ayarları"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
        loadValues()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    public func show() {
        loadValues()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildContent() {
        sensitivityPopup.addItems(withTitles: ["Düşük", "Orta", "Yüksek"])
        sensitivityPopup.target = self
        sensitivityPopup.action = #selector(sensitivityChanged)

        modePopup.addItems(withTitles: ["Taşı (varsayılan)", "Kopyala"])
        modePopup.target = self
        modePopup.action = #selector(modeChanged)

        autoOpenCheckbox.target = self
        autoOpenCheckbox.action = #selector(autoOpenChanged)

        shiftCheckbox.target = self
        shiftCheckbox.action = #selector(shiftChanged)

        loginCheckbox.target = self
        loginCheckbox.action = #selector(loginChanged)

        let grid = NSGridView(views: [
            [makeLabel("Sallama hassasiyeti:"), sensitivityPopup],
            [makeLabel("Bırakınca:"), modePopup],
            [NSGridCell.emptyContentView, autoOpenCheckbox],
            [NSGridCell.emptyContentView, shiftCheckbox],
            [NSGridCell.emptyContentView, loginCheckbox],
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.translatesAutoresizingMaskIntoConstraints = false

        guard let content = window?.contentView else { return }
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: content.centerYAnchor),
        ])
    }

    private func makeLabel(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    private func loadValues() {
        switch settings.sensitivity {
        case .low: sensitivityPopup.selectItem(at: 0)
        case .medium: sensitivityPopup.selectItem(at: 1)
        case .high: sensitivityPopup.selectItem(at: 2)
        }
        modePopup.selectItem(at: settings.transferMode == .move ? 0 : 1)
        autoOpenCheckbox.state = settings.autoOpenEnabled ? .on : .off
        shiftCheckbox.state = settings.shiftTriggerEnabled ? .on : .off
        loginCheckbox.state = settings.launchAtLogin ? .on : .off
    }

    @objc private func sensitivityChanged() {
        let values: [ShakeDetector.Sensitivity] = [.low, .medium, .high]
        settings.sensitivity = values[max(0, sensitivityPopup.indexOfSelectedItem)]
    }

    @objc private func modeChanged() {
        settings.transferMode = modePopup.indexOfSelectedItem == 0 ? .move : .copy
    }

    @objc private func autoOpenChanged() {
        settings.autoOpenEnabled = autoOpenCheckbox.state == .on
    }

    @objc private func shiftChanged() {
        settings.shiftTriggerEnabled = shiftCheckbox.state == .on
    }

    @objc private func loginChanged() {
        let enable = loginCheckbox.state == .on
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            settings.launchAtLogin = enable
        } catch {
            // Uygulama .app paketi olarak çalışmıyorsa (salt binary) sistem kaydı yapılamaz.
            loginCheckbox.state = enable ? .off : .on
            let alert = NSAlert()
            alert.messageText = "Girişte başlatma ayarlanamadı"
            alert.informativeText =
                "Bu özellik uygulama .app paketi olarak çalışırken kullanılabilir. "
                + "README'deki make-app adımıyla Droper.app oluşturup onu çalıştırın.\n\n(\(error.localizedDescription))"
            alert.runModal()
        }
    }
}
