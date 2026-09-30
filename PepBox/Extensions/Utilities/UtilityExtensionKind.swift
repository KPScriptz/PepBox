//
//  UtilityExtensionKind.swift
//  PepBox
//
//  Background extensions without a shelf panel (Ring, Key Sounds). Installed from
//  the Extension Store; each one is started or stopped to match its state.
//

import SwiftUI
import DropClip

enum UtilityExtensionKind: String, CaseIterable {
    case ring
    case keySounds
    case quickSearch
    case textActions
    case smoothScroll
    case eyeBreaks
    case downloadsActivity
    case localSend

    init?(extensionType: ExtensionType) {
        guard let kind = Self.allCases.first(where: { $0.extensionType == extensionType }) else { return nil }
        self = kind
    }

    var extensionType: ExtensionType {
        switch self {
        case .ring: return .ring
        case .keySounds: return .keySounds
        case .quickSearch: return .quickSearch
        case .textActions: return .textActions
        case .smoothScroll: return .smoothScroll
        case .eyeBreaks: return .eyeBreaks
        case .downloadsActivity: return .downloadsActivity
        case .localSend: return .localSend
        }
    }

    var installedKey: String { "utilityExtension_\(rawValue)_installed" }

    var isInstalled: Bool { UserDefaults.standard.bool(forKey: installedKey) }

    /// Installed and not turned off in the Extension Store.
    var isAvailable: Bool { isInstalled && !extensionType.isRemoved }

    func install() {
        UserDefaults.standard.set(true, forKey: installedKey)
        extensionType.setRemoved(false)
        NotificationCenter.default.post(name: .extensionStateChanged, object: extensionType)
        applyState()
    }

    /// Starts or stops the extension to match whether it's available.
    func applyState() {
        switch self {
        case .ring: RingMenuController.shared.setEnabled(isAvailable)
        case .keySounds: KeySoundsManager.shared.setEnabled(isAvailable)
        case .quickSearch: QuickSearchController.shared.setEnabled(isAvailable)
        case .textActions: isAvailable ? TextActions.start() : TextActions.stop()
        case .smoothScroll: SmoothScrollController.shared.setEnabled(isAvailable)
        case .eyeBreaks: EyeBreakManager.shared.setEnabled(isAvailable)
        case .downloadsActivity: DownloadsWatcher.shared.setEnabled(isAvailable)
        case .localSend: LocalSendReceiver.shared.setEnabled(isAvailable)
        }
    }

    func cleanup() {
        switch self {
        case .ring: RingMenuController.shared.setEnabled(false)
        case .keySounds: KeySoundsManager.shared.setEnabled(false)
        case .quickSearch: QuickSearchController.shared.setEnabled(false)
        case .textActions: TextActions.stop()
        case .smoothScroll: SmoothScrollController.shared.setEnabled(false)
        case .eyeBreaks: EyeBreakManager.shared.setEnabled(false)
        case .downloadsActivity: DownloadsWatcher.shared.setEnabled(false)
        case .localSend: LocalSendReceiver.shared.setEnabled(false)
        }
    }

    private static var stateObserver: NSObjectProtocol?

    /// Called at launch: start what's installed and follow later Turn On / Turn Off changes.
    static func startAll() {
        allCases.forEach { $0.applyState() }
        AgentsMonitor.shared.sync()
        guard stateObserver == nil else { return }
        stateObserver = NotificationCenter.default.addObserver(
            forName: .extensionStateChanged, object: nil, queue: .main
        ) { _ in
            // Let the Store finish updating the removed flag first.
            DispatchQueue.main.async {
                allCases.forEach { $0.applyState() }
                AgentsMonitor.shared.sync()
            }
        }
    }
}

struct RingExtension: ExtensionDefinition {
    static let id = "ring"
    static let title = "Ring"
    static let subtitle = "Actions in a circle at your cursor"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .purple
    static let description = "Press ⌥⇧Space to open a ring of quick actions right where your pointer is: clipboard, shelf, basket, screenshot to shelf, grab text from the screen, color picker, Pomodoro, keep awake and settings."
    static let features: [(icon: String, text: String)] = [
        ("circle.dashed", "Opens at the pointer with ⌥⇧Space"),
        ("camera.viewfinder", "Screenshot straight onto the shelf"),
        ("text.viewfinder", "Grab Text: select an area, its text is copied"),
        ("eyedropper", "Pick any color on screen, copied as hex"),
        ("escape", "Esc or click away to close")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "circle.dashed"
    static let iconPlaceholderColor: Color = .purple
    static func cleanup() { UtilityExtensionKind.ring.cleanup() }
}

struct KeySoundsExtension: ExtensionDefinition {
    static let id = "keySounds"
    static let title = "Key Sounds"
    static let subtitle = "Mechanical keyboard sounds"
    static let category: ExtensionGroup = .media
    static let categoryColor: Color = .brown
    static let description = "Hear a mechanical keyboard click as you type. The sounds are generated on your Mac, with a deeper thock for space, return, delete and tab."
    static let features: [(icon: String, text: String)] = [
        ("keyboard", "Click on every key press"),
        ("space", "Deeper sound for space and return"),
        ("waveform", "Generated on your Mac, no audio files")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "keyboard"
    static let iconPlaceholderColor: Color = .brown
    static func cleanup() { UtilityExtensionKind.keySounds.cleanup() }
}

struct QuickSearchExtension: ExtensionDefinition {
    static let id = "quickSearch"
    static let title = "Quick Search"
    static let subtitle = "Search bar for apps, files and math"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .teal
    static let description = "Press ⌃⌥Space for a search bar: launch apps, open files from your home folder, do math (12*4, (3+2)^2), convert units (5 km to mi, 70 f to c, 2 gb in mb) and currencies ($20 to eur, 100 gbp in jpy, daily rates), start timers (timer 5m tea) that count down beside the notch, and run commands: lock, sleep, restart, eject, quit <app>, any System Settings page, or search the web. Enter opens or copies; ⌘Enter shows a file in Finder."
    static let features: [(icon: String, text: String)] = [
        ("app.badge", "Launch apps"),
        ("doc.text.magnifyingglass", "Find files by name"),
        ("plus.forwardslash.minus", "Math, units and currency, Enter copies"),
        ("timer", "Timers beside the notch: \"timer 10m pizza\""),
        ("power", "Commands: lock, sleep, restart, eject, quit an app"),
        ("gearshape", "Jump to any System Settings page"),
        ("globe", "Search the web when nothing matches"),
        ("wand.and.stars", "Tools: colors, time zones, dates, hex, %, UUID, passwords, base64"),
        ("book.fill", "define <word>, cb <text>, downloads, ip, port 3000, awake 1h, :emoji, count"),
        ("checklist", "note …, todo …, remind … in 20m, join, agenda, weather, play/next"),
        ("xmark.app", "force quit / hide <app>, battery, uptime"),
        ("keyboard", "Arrow keys to pick, Esc to close")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "magnifyingglass"
    static let iconPlaceholderColor: Color = .teal
    static func cleanup() { UtilityExtensionKind.quickSearch.cleanup() }
}

struct TextActionsExtension: ExtensionDefinition {
    static let id = "textActions"
    static let title = "Text Actions"
    static let subtitle = "Action bar for selected text"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .cyan
    static let description = "Select text anywhere and a pill appears beside it: copy, search, translate, AI rewrite with your own provider or an on-device model, and every action you set up, including snippets, links, scripts and extensions. Per-app rules, hold-to-summon and a ⌥⌘C search palette. Based on DropClip (MIT) and OpenClip by Ganesh M, with OpenSelection (Apache-2.0)."
    static let features: [(icon: String, text: String)] = [
        ("cursorarrow.and.square.on.square.dashed", "Pill beside any selection"),
        ("sparkles", "AI rewrite: your own key or on-device"),
        ("square.stack.3d.up", "Custom actions, groups and extensions"),
        ("app.badge.checkmark", "Per-app rules"),
        ("doc.plaintext", "Credits and licences under Options")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "text.cursor"
    static let iconPlaceholderColor: Color = .cyan
    static func cleanup() { UtilityExtensionKind.textActions.cleanup() }
}

struct SmoothScrollExtension: ExtensionDefinition {
    static let id = "smoothScroll"
    static let title = "Smooth Scroll"
    static let subtitle = "Trackpad-smooth mouse wheels"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .indigo
    static let description = "Turns a mouse wheel's jumpy line steps into short, eased glides, so scrolling feels like a trackpad. Trackpads and Magic Mouse are left untouched. Needs Accessibility."
    static let features: [(icon: String, text: String)] = [
        ("computermouse", "Smooth steps for regular mouse wheels"),
        ("hand.draw", "Trackpad and Magic Mouse scrolling unchanged"),
        ("arrow.up.arrow.down", "Changing direction stops the glide at once")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "computermouse"
    static let iconPlaceholderColor: Color = .indigo
    static func cleanup() { UtilityExtensionKind.smoothScroll.cleanup() }
}
