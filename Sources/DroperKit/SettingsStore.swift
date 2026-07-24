import Foundation

/// UserDefaults üzerinde uygulama ayarları.
public final class SettingsStore {
    public static let shared = SettingsStore()

    private enum Key {
        static let sensitivity = "shakeSensitivity"
        static let transferMode = "transferMode"
        static let shiftTrigger = "shiftTriggerEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let autoOpen = "autoOpenOnDrag"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.sensitivity: ShakeDetector.Sensitivity.medium.rawValue,
            Key.transferMode: TransferMode.move.rawValue,
            Key.shiftTrigger: true,
            Key.launchAtLogin: false,
            Key.autoOpen: true,
        ])
    }

    public var sensitivity: ShakeDetector.Sensitivity {
        get {
            ShakeDetector.Sensitivity(rawValue: defaults.string(forKey: Key.sensitivity) ?? "")
                ?? .medium
        }
        set { defaults.set(newValue.rawValue, forKey: Key.sensitivity) }
    }

    public var transferMode: TransferMode {
        get { TransferMode(rawValue: defaults.string(forKey: Key.transferMode) ?? "") ?? .move }
        set { defaults.set(newValue.rawValue, forKey: Key.transferMode) }
    }

    public var shiftTriggerEnabled: Bool {
        get { defaults.bool(forKey: Key.shiftTrigger) }
        set { defaults.set(newValue, forKey: Key.shiftTrigger) }
    }

    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }

    /// Dosya sürüklemesi ~1 sn sürünce rafın kendiliğinden açılması.
    public var autoOpenEnabled: Bool {
        get { defaults.bool(forKey: Key.autoOpen) }
        set { defaults.set(newValue, forKey: Key.autoOpen) }
    }
}
