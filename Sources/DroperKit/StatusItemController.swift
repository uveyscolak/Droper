import AppKit

/// Menü çubuğu ikonu ve menüsü: Yeni Raf, Ayarlar, Çık.
public final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let onNewShelf: () -> Void
    private let onSettings: () -> Void

    public init(onNewShelf: @escaping () -> Void, onSettings: @escaping () -> Void) {
        self.onNewShelf = onNewShelf
        self.onSettings = onSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "tray.full", accessibilityDescription: "Droper")
            button.toolTip = "Droper"
        }

        let menu = NSMenu()
        menu.addItem(makeItem(title: "Yeni Raf", action: #selector(newShelf), key: "n"))
        menu.addItem(makeItem(title: "Ayarlar…", action: #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(makeItem(title: "Droper'dan Çık", action: #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func makeItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func newShelf() {
        onNewShelf()
    }

    @objc private func openSettings() {
        onSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
