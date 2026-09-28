//
//  ExtensionOptionsView.swift
//  PepBox
//
//  Options shown in an installed extension's info sheet (shortcuts, volume).
//

import SwiftUI
import Carbon.HIToolbox

enum ExtensionShortcuts {
    static let ringKey = "ring_shortcut"
    static let quickSearchKey = "quickSearch_shortcut"

    static let ringDefault = SavedShortcut(keyCode: kVK_Space, modifiers: NSEvent.ModifierFlags([.option, .shift]).rawValue)
    static let quickSearchDefault = SavedShortcut(keyCode: kVK_Space, modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue)

    static func load(_ key: String, default defaultValue: SavedShortcut) -> SavedShortcut {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) else { return defaultValue }
        return decoded
    }

    static func save(_ shortcut: SavedShortcut?, key: String) {
        if let shortcut, let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

struct ExtensionOptionsView: View {
    let extensionType: ExtensionType

    static func hasOptions(_ type: ExtensionType) -> Bool {
        [.ring, .quickSearch, .keySounds].contains(type)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Options")
                .font(.headline)
            switch extensionType {
            case .ring:
                ShortcutOption(
                    title: "Open Ring",
                    key: ExtensionShortcuts.ringKey,
                    defaultShortcut: ExtensionShortcuts.ringDefault
                ) { RingMenuController.shared.reloadShortcut() }
            case .quickSearch:
                ShortcutOption(
                    title: "Open Quick Search",
                    key: ExtensionShortcuts.quickSearchKey,
                    defaultShortcut: ExtensionShortcuts.quickSearchDefault
                ) { QuickSearchController.shared.reloadShortcut() }
            case .keySounds:
                KeySoundsVolumeOption()
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ShortcutOption: View {
    let title: String
    let key: String
    let defaultShortcut: SavedShortcut
    let onChange: () -> Void

    @State private var shortcut: SavedShortcut?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            KeyShortcutRecorder(shortcut: Binding(
                get: { shortcut },
                set: { newValue in
                    shortcut = newValue ?? defaultShortcut
                    ExtensionShortcuts.save(newValue, key: key)
                    onChange()
                }
            ))
            Button {
                shortcut = defaultShortcut
                ExtensionShortcuts.save(nil, key: key)
                onChange()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help("Reset to \(defaultShortcut.description)")
        }
        .onAppear { shortcut = ExtensionShortcuts.load(key, default: defaultShortcut) }
    }
}

private struct KeySoundsVolumeOption: View {
    @State private var volume: Double = Double(KeySoundsManager.shared.volume)

    var body: some View {
        HStack {
            Image(systemName: "speaker.fill").foregroundStyle(.secondary)
            Slider(value: $volume, in: 0...1)
                .onChange(of: volume) { _, value in KeySoundsManager.shared.volume = Float(value) }
            Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
        }
    }
}
