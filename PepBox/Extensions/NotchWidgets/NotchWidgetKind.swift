//
//  NotchWidgetKind.swift
//  PepBox
//
//  Small panels that open from a button under the expanded shelf.
//  One slot in NotchShelfView hosts whichever widget is active, so each new
//  widget only needs a case here, a view, and an extension definition.
//

import SwiftUI

enum NotchWidgetKind: String, CaseIterable, Identifiable {
    case pomodoro
    case emojiPicker
    case teleprompter
    case meetings
    case appVolume
    case obsidian
    case systemStats
    case upNext
    case shortcuts

    var id: String { rawValue }

    init?(extensionType: ExtensionType) {
        guard let kind = Self.allCases.first(where: { $0.extensionType == extensionType }) else { return nil }
        self = kind
    }

    var extensionType: ExtensionType {
        switch self {
        case .pomodoro: return .pomodoro
        case .emojiPicker: return .emojiPicker
        case .teleprompter: return .teleprompter
        case .meetings: return .meetings
        case .appVolume: return .appVolume
        case .obsidian: return .obsidian
        case .systemStats: return .systemStats
        case .upNext: return .upNext
        case .shortcuts: return .shortcuts
        }
    }

    var title: String { extensionType.title }

    var icon: String {
        switch self {
        case .pomodoro: return "timer"
        case .emojiPicker: return "face.smiling"
        case .teleprompter: return "text.alignleft"
        case .meetings: return "video.fill"
        case .appVolume: return "speaker.wave.2.fill"
        case .obsidian: return "note.text"
        case .systemStats: return "gauge.with.dots.needle.67percent"
        case .upNext: return "calendar.badge.clock"
        case .shortcuts: return "square.2.layers.3d.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pomodoro: return .red
        case .emojiPicker: return .yellow
        case .teleprompter: return .mint
        case .meetings: return .blue
        case .appVolume: return .green
        case .obsidian: return .purple
        case .systemStats: return .teal
        case .upNext: return .orange
        case .shortcuts: return .indigo
        }
    }

    var installedKey: String { "notchWidget_\(rawValue)_installed" }

    var isInstalled: Bool { UserDefaults.standard.bool(forKey: installedKey) }

    /// Installed and not turned off in the Extension Store.
    var isAvailable: Bool { isInstalled && !extensionType.isRemoved }

    /// Available widgets in the user's chosen order (Settings → Shelf → Widget Buttons).
    static var available: [NotchWidgetKind] { ordered.filter(\.isAvailable) }

    private static let orderKey = "notchWidgetOrder"

    /// All widgets in the saved order; ones added later go at the end.
    static var ordered: [NotchWidgetKind] {
        let saved = (UserDefaults.standard.stringArray(forKey: orderKey) ?? []).compactMap(NotchWidgetKind.init(rawValue:))
        return saved + allCases.filter { !saved.contains($0) }
    }

    static func saveOrder(_ kinds: [NotchWidgetKind]) {
        // Keep widgets that aren't in the list (not installed) in their old relative place at the end.
        let rest = ordered.filter { !kinds.contains($0) }
        UserDefaults.standard.set((kinds + rest).map(\.rawValue), forKey: orderKey)
    }

    /// True while a widget that must stay readable (the teleprompter) is open,
    /// so auto-collapse and click-outside don't close the shelf under it.
    static var isHoldingShelfOpen = false

    func install() {
        UserDefaults.standard.set(true, forKey: installedKey)
        extensionType.setRemoved(false)
        NotificationCenter.default.post(name: .extensionStateChanged, object: extensionType)
    }

    func cleanup() {
        switch self {
        case .pomodoro: PomodoroManager.shared.reset()
        case .teleprompter: TeleprompterManager.shared.pause()
        case .appVolume: AppVolumeManager.shared.resetAll()
        case .emojiPicker, .meetings, .obsidian, .systemStats, .upNext, .shortcuts: break
        }
    }
}

/// Hosts the active widget's panel inside the expanded shelf.
struct NotchWidgetPanel: View {
    let kind: NotchWidgetKind
    var notchHeight: CGFloat = 0
    var isExternalWithNotchStyle: Bool = false

    var body: some View {
        Group {
            switch kind {
            case .pomodoro:
                PomodoroNotchView(manager: PomodoroManager.shared)
            case .emojiPicker:
                EmojiPickerNotchView()
            case .teleprompter:
                TeleprompterNotchView(manager: TeleprompterManager.shared)
            case .meetings:
                MeetingsNotchView(manager: MeetingsManager.shared)
            case .appVolume:
                AppVolumeNotchView(manager: AppVolumeManager.shared)
            case .obsidian:
                ObsidianNotchView(manager: ObsidianManager.shared)
            case .systemStats:
                SystemStatsNotchView(manager: SystemStatsManager.shared)
            case .upNext:
                UpNextNotchView(calendar: UpNextCalendar.shared, weather: UpNextWeather.shared)
            case .shortcuts:
                ShortcutsNotchView(manager: ShortcutsWidgetManager.shared)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(NotchLayoutConstants.contentEdgeInsets(notchHeight: notchHeight, isExternalWithNotchStyle: isExternalWithNotchStyle))
    }
}
