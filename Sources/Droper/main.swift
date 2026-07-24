import AppKit
import DroperKit

// Alt komut: dosya işlemlerinin uçtan uca kanıtı (UI gerektirmez).
if CommandLine.arguments.dropFirst().first == "droper-transfer-smoke" {
    do {
        try SmokeTest.run()
        print("SMOKE OK")
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("SMOKE FAIL: \(error)\n".utf8))
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
print("Droper started (menu bar)")
fflush(stdout)
app.run()
