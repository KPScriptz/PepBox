//
//  UtilityExtensionKind.swift
//  PepBox
//
//  Background extensions without a shelf panel (Ring, Key Sounds). Installed from
//  the Extension Store; each one is started or stopped to match its state.
//

import SwiftUI

enum UtilityExtensionKind: String, CaseIterable {
    case ring
    case keySounds
    case quickSearch
    case textActions

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
        case .textActions: TextActionsController.shared.setEnabled(isAvailable)
        }
    }

    func cleanup() {
        switch self {
        case .ring: RingMenuController.shared.setEnabled(false)
        case .keySounds: KeySoundsManager.shared.setEnabled(false)
        case .quickSearch: QuickSearchController.shared.setEnabled(false)
        case .textActions: TextActionsController.shared.setEnabled(false)
        }
    }

    private static var stateObserver: NSObjectProtocol?

    /// Called at launch: start what's installed and follow later Turn On / Turn Off changes.
    static func startAll() {
        allCases.forEach { $0.applyState() }
        guard stateObserver == nil else { return }
        stateObserver = NotificationCenter.default.addObserver(
            forName: .extensionStateChanged, object: nil, queue: .main
        ) { _ in
            // Let the Store finish updating the removed flag first.
            DispatchQueue.main.async { allCases.forEach { $0.applyState() } }
        }
    }
}

struct RingExtension: ExtensionDefinition {
    static let id = "ring"
    static let title = "Ring"
    static let subtitle = "Actions in a circle at your cursor"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .purple
    static let description = "Press ⌥⇧Space to open a ring of quick actions right where your pointer is: clipboard, shelf, basket, screenshot to shelf, color picker, Pomodoro, keep awake and settings."
    static let features: [(icon: String, text: String)] = [
        ("circle.dashed", "Opens at the pointer with ⌥⇧Space"),
        ("camera.viewfinder", "Screenshot straight onto the shelf"),
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
    static let description = "Press ⌃⌥Space for a search bar: launch apps, open files from your home folder, do math (12*4, (3+2)^2) and convert units (5 km to mi, 70 f to c, 2 gb in mb). Enter opens or copies; ⌘Enter shows a file in Finder."
    static let features: [(icon: String, text: String)] = [
        ("app.badge", "Launch apps"),
        ("doc.text.magnifyingglass", "Find files by name"),
        ("plus.forwardslash.minus", "Math and unit conversion, Enter copies"),
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
    static let description = "Select text in any app and a small bar appears: copy, search the web, translate, look it up in Dictionary, read it aloud or drop it on the shelf as a text file. Needs Accessibility; your clipboard isn't touched and password fields are ignored."
    static let features: [(icon: String, text: String)] = [
        ("cursorarrow.and.square.on.square.dashed", "Appears after dragging or double-clicking text"),
        ("magnifyingglass", "Search, translate, define, speak"),
        ("tray.and.arrow.down", "Save the selection to the shelf"),
        ("lock.shield", "Skips password fields")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "text.cursor"
    static let iconPlaceholderColor: Color = .cyan
    static func cleanup() { UtilityExtensionKind.textActions.cleanup() }
}
