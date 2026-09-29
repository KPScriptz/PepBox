//
//  QuickCommands.swift
//  PepBox
//
//  Things Quick Search can do, not just find: lock, sleep, restart, eject,
//  quit apps, open System Settings pages and search the web.
//

import AppKit

enum QuickCommand: Equatable {
    case lock
    case sleep
    case restart
    case shutDown
    case logOut
    case ejectAll
    case quitApp(name: String, pid: pid_t)
    case settings(name: String, pane: String)
    case webSearch(String)

    var title: String {
        switch self {
        case .lock: return "Lock Screen"
        case .sleep: return "Sleep"
        case .restart: return "Restart…"
        case .shutDown: return "Shut Down…"
        case .logOut: return "Log Out…"
        case .ejectAll: return "Eject All Disks"
        case .quitApp(let name, _): return "Quit \(name)"
        case .settings(let name, _): return "\(name) Settings"
        case .webSearch(let text): return "Search the web for “\(text)”"
        }
    }

    var subtitle: String {
        switch self {
        case .restart, .shutDown, .logOut: return "Command · macOS asks to confirm"
        case .settings: return "System Settings"
        case .webSearch: return "Opens in your browser"
        default: return "Command"
        }
    }

    var symbol: String {
        switch self {
        case .lock: return "lock.fill"
        case .sleep: return "moon.fill"
        case .restart: return "arrow.clockwise"
        case .shutDown: return "power"
        case .logOut: return "rectangle.portrait.and.arrow.right"
        case .ejectAll: return "eject.fill"
        case .quitApp: return "xmark.app.fill"
        case .settings: return "gearshape.fill"
        case .webSearch: return "globe"
        }
    }

    // MARK: Matching

    private static let fixed: [(QuickCommand, [String])] = [
        (.lock, ["lock", "lock screen"]),
        (.sleep, ["sleep"]),
        (.restart, ["restart", "reboot"]),
        (.shutDown, ["shut down", "shutdown", "power off"]),
        (.logOut, ["log out", "logout", "sign out"]),
        (.ejectAll, ["eject", "eject all", "eject disks"])
    ]

    /// Settings pages by name → pane identifier for x-apple.systempreferences.
    static let settingsPanes: [(String, String)] = [
        ("Wi-Fi", "com.apple.wifi-settings-extension"),
        ("Bluetooth", "com.apple.BluetoothSettings"),
        ("Network", "com.apple.Network-Settings.extension"),
        ("Notifications", "com.apple.Notifications-Settings.extension"),
        ("Sound", "com.apple.Sound-Settings.extension"),
        ("Focus", "com.apple.Focus-Settings.extension"),
        ("Screen Time", "com.apple.Screen-Time-Settings.extension"),
        ("General", "com.apple.systempreferences.GeneralSettings"),
        ("Appearance", "com.apple.Appearance-Settings.extension"),
        ("Accessibility", "com.apple.Accessibility-Settings.extension"),
        ("Desktop & Dock", "com.apple.Desktop-Settings.extension"),
        ("Displays", "com.apple.Displays-Settings.extension"),
        ("Wallpaper", "com.apple.Wallpaper-Settings.extension"),
        ("Battery", "com.apple.Battery-Settings.extension"),
        ("Privacy & Security", "com.apple.settings.PrivacySecurity.extension"),
        ("Login Items", "com.apple.LoginItems-Settings.extension"),
        ("Software Update", "com.apple.Software-Update-Settings.extension"),
        ("Users & Groups", "com.apple.Users-Groups-Settings.extension"),
        ("Keyboard", "com.apple.Keyboard-Settings.extension"),
        ("Trackpad", "com.apple.Trackpad-Settings.extension"),
        ("Mouse", "com.apple.Mouse-Settings.extension"),
        ("Printers & Scanners", "com.apple.Print-Scanner-Settings.extension"),
        ("Storage", "com.apple.settings.Storage")
    ]

    /// Commands for a query. `runningApps` is (name, pid) for regular apps, passed in so this stays testable.
    static func matches(_ query: String, runningApps: [(String, pid_t)] = []) -> [QuickCommand] {
        let text = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard text.count >= 2 else { return [] }
        var results: [QuickCommand] = []

        for (command, keywords) in fixed where keywords.contains(where: { $0.hasPrefix(text) || (text.count >= 4 && text.hasPrefix($0)) }) {
            results.append(command)
        }

        if text.hasPrefix("quit ") {
            let name = text.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                results += runningApps
                    .filter { $0.0.lowercased().hasPrefix(name) }
                    .prefix(4)
                    .map { .quitApp(name: $0.0, pid: $0.1) }
            }
        }

        let settingsQuery = text.hasSuffix(" settings") ? String(text.dropLast(9)) : text
        if settingsQuery.count >= 3 {
            results += settingsPanes
                .filter { name, _ in
                    let lower = name.lowercased()
                    return lower.hasPrefix(settingsQuery) || lower.split(separator: " ").contains { $0.hasPrefix(settingsQuery) }
                }
                .prefix(3)
                .map { .settings(name: $0.0, pane: $0.1) }
        }
        return results
    }

    // MARK: Running

    func run() {
        switch self {
        case .lock:
            // ⌃⌘Q, the system Lock Screen shortcut.
            let source = CGEventSource(stateID: .hidSystemState)
            let down = CGEvent(keyboardEventSource: source, virtualKey: 12, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: 12, keyDown: false)
            down?.flags = [.maskCommand, .maskControl]
            up?.flags = [.maskCommand, .maskControl]
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        case .sleep:
            Self.launch("/usr/bin/pmset", ["sleepnow"])
        case .restart:
            Self.askLoginWindow("rrst")
        case .shutDown:
            Self.askLoginWindow("rsdn")
        case .logOut:
            Self.askLoginWindow("logo")
        case .ejectAll:
            let keys: [URLResourceKey] = [.volumeIsEjectableKey, .volumeIsRemovableKey]
            let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
            for volume in volumes {
                let values = try? volume.resourceValues(forKeys: Set(keys))
                if values?.volumeIsEjectable == true || values?.volumeIsRemovable == true {
                    try? NSWorkspace.shared.unmountAndEjectDevice(at: volume)
                }
            }
        case .quitApp(_, let pid):
            NSRunningApplication(processIdentifier: pid)?.terminate()
        case .settings(_, let pane):
            if let url = URL(string: "x-apple.systempreferences:\(pane)") { NSWorkspace.shared.open(url) }
        case .webSearch(let text):
            var components = URLComponents(string: "https://www.google.com/search")
            components?.queryItems = [URLQueryItem(name: "q", value: text)]
            if let url = components?.url { NSWorkspace.shared.open(url) }
        }
    }

    /// Sends the loginwindow "really restart / shut down / log out" event, which shows macOS's own confirmation.
    private static func askLoginWindow(_ code: String) {
        let script = "tell application \"loginwindow\" to «event aevt\(code)»"
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
        }
    }

    private static func launch(_ path: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try? process.run()
    }
}
