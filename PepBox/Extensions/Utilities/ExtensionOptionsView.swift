//
//  ExtensionOptionsView.swift
//  PepBox
//
//  Options shown in an installed extension's info sheet (shortcuts, volume).
//

import SwiftUI
import Carbon.HIToolbox
import DropClip

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
        [.ring, .quickSearch, .keySounds, .textActions, .eyeBreaks, .downloadsActivity, .localSend].contains(type)
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
                RingActionsOption()
            case .quickSearch:
                ShortcutOption(
                    title: "Open Quick Search",
                    key: ExtensionShortcuts.quickSearchKey,
                    defaultShortcut: ExtensionShortcuts.quickSearchDefault
                ) { QuickSearchController.shared.reloadShortcut() }
            case .keySounds:
                KeySoundsVolumeOption()
            case .textActions:
                HStack {
                    Text("Actions, AI, shortcuts and app rules")
                    Spacer()
                    Button("Open Settings") { TextActions.openSettings() }
                }
                Text("Based on DropClip (MIT) and OpenClip by Ganesh M, with OpenSelection (Apache-2.0). Licences: Text Actions settings → About.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .eyeBreaks:
                EyeBreakOptions()
            case .downloadsActivity:
                DownloadsOptions()
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ShortcutOption: View {
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

private struct EyeBreakOptions: View {
    @AppStorage(EyeBreakManager.workMinutesKey) private var minutes = 20
    @AppStorage(EyeBreakManager.soundKey) private var sound = true
    @AppStorage(EyeBreakManager.waterMinutesKey) private var water = 0

    var body: some View {
        Stepper("Break every \(minutes) minutes", value: $minutes, in: 5...90, step: 5)
        Toggle("Play a sound at start and end", isOn: $sound)
        Picker("Water reminder", selection: $water) {
            Text("Off").tag(0)
            Text("Every 45 min").tag(45)
            Text("Every hour").tag(60)
            Text("Every 90 min").tag(90)
        }
    }
}

private struct DownloadsOptions: View {
    @AppStorage(DownloadsWatcher.addToShelfKey) private var addToShelf = true

    var body: some View {
        Toggle("Put finished downloads on the shelf", isOn: $addToShelf)
    }
}

private struct RingActionsOption: View {
    @State private var enabled = RingMenuController.enabledActionIDs

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Actions (up to \(RingMenuController.maxActions))")
                .font(.subheadline.weight(.semibold))
            ForEach(RingMenuController.catalog) { action in
                Toggle(isOn: Binding(
                    get: { enabled.contains(action.id) },
                    set: { isOn in
                        RingMenuController.setAction(action.id, enabled: isOn)
                        enabled = RingMenuController.enabledActionIDs
                    }
                )) {
                    Label(action.title, systemImage: action.icon)
                }
                .disabled(isOn(action) ? enabled.count <= 1 : enabled.count >= RingMenuController.maxActions)
            }
        }
    }

    private func isOn(_ action: RingAction) -> Bool { enabled.contains(action.id) }
}
