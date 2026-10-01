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
    case agents
    case notes
    case worldClock
    case calculator
    case dice
    case colorPicker
    case countdown
    case stopwatchWidget
    case timers
    case habits
    case water
    case breathe
    case network
    case recentClips
    case recentDownloads
    case screenshots
    case quickLinks
    case passwordGenerator
    case dayProgress
    case moonPhase
    case counter
    case monthCalendar

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
        case .agents: return .agents
        case .notes: return .quickNotes
        case .worldClock: return .worldClock
        case .calculator: return .calculator
        case .dice: return .dice
        case .colorPicker: return .colorPicker
        case .countdown: return .countdown
        case .stopwatchWidget: return .stopwatchWidget
        case .timers: return .timers
        case .habits: return .habits
        case .water: return .water
        case .breathe: return .breathe
        case .network: return .network
        case .recentClips: return .recentClips
        case .recentDownloads: return .recentDownloads
        case .screenshots: return .screenshots
        case .quickLinks: return .quickLinks
        case .passwordGenerator: return .passwordGenerator
        case .dayProgress: return .dayProgress
        case .moonPhase: return .moonPhase
        case .counter: return .counter
        case .monthCalendar: return .monthCalendar
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
        case .agents: return "sparkle"
        case .notes: return "note.text.badge.plus"
        case .worldClock: return "clock.fill"
        case .calculator: return "wrench.and.screwdriver.fill"
        case .dice: return "dice.fill"
        case .colorPicker: return "eyedropper"
        case .countdown: return "hourglass"
        case .stopwatchWidget: return "stopwatch"
        case .timers: return "timer"
        case .habits: return "heart.fill"
        case .water: return "drop.fill"
        case .breathe: return "wind"
        case .network: return "network"
        case .recentClips: return "clock.arrow.circlepath"
        case .recentDownloads: return "arrow.down.circle.fill"
        case .screenshots: return "camera.viewfinder"
        case .quickLinks: return "link"
        case .passwordGenerator: return "key.fill"
        case .dayProgress: return "chart.bar.fill"
        case .moonPhase: return "moon.stars.fill"
        case .counter: return "number.circle.fill"
        case .monthCalendar: return "calendar"
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
        case .agents: return .orange
        case .notes: return .yellow
        case .worldClock: return .cyan
        case .calculator: return .orange
        case .dice: return .red
        case .colorPicker: return .pink
        case .countdown: return .purple
        case .stopwatchWidget: return .mint
        case .timers: return .orange
        case .habits: return .green
        case .water: return .cyan
        case .breathe: return .teal
        case .network: return .blue
        case .recentClips: return .indigo
        case .recentDownloads: return .blue
        case .screenshots: return .teal
        case .quickLinks: return .indigo
        case .passwordGenerator: return .yellow
        case .dayProgress: return .orange
        case .moonPhase: return .gray
        case .counter: return .pink
        case .monthCalendar: return .red
        }
    }

    var installedKey: String { "notchWidget_\(rawValue)_installed" }

    var isInstalled: Bool { UserDefaults.standard.bool(forKey: installedKey) }

    /// Installed and not turned off in the Extension Store.
    var isAvailable: Bool { isInstalled && !extensionType.isRemoved }

    /// Available widgets in the user's chosen order (Settings → Shelf → Widget Buttons).
    static var available: [NotchWidgetKind] { ordered.filter { $0.isAvailable && $0.mergedInto == nil } }

    // MARK: Combined widgets

    /// The tabs of a combined widget (the first tab is the widget's own view), or [] for a plain one.
    var tabs: [NotchWidgetKind] {
        switch self {
        case .worldClock: return [.worldClock, .monthCalendar, .dayProgress, .moonPhase, .countdown]
        case .timers: return [.timers, .stopwatchWidget]
        case .habits: return [.habits, .water, .breathe]
        case .calculator: return [.calculator, .dice, .passwordGenerator, .colorPicker, .counter, .network]
        case .recentClips: return [.recentClips, .recentDownloads, .screenshots, .quickLinks]
        default: return []
        }
    }

    /// The combined widget this one is now a tab of.
    var mergedInto: NotchWidgetKind? {
        Self.allCases.first { $0 != self && $0.tabs.contains(self) }
    }

    /// Short name on a tab.
    var tabTitle: String {
        switch self {
        case .worldClock: return "Clock"
        case .monthCalendar: return "Month"
        case .dayProgress: return "Day"
        case .moonPhase: return "Moon"
        case .countdown: return "Countdown"
        case .timers: return "Timers"
        case .stopwatchWidget: return "Stopwatch"
        case .habits: return "Habits"
        case .water: return "Water"
        case .breathe: return "Breathe"
        case .calculator: return "Calc"
        case .dice: return "Dice"
        case .passwordGenerator: return "Password"
        case .colorPicker: return "Color"
        case .counter: return "Counter"
        case .network: return "Network"
        case .recentClips: return "Clips"
        case .recentDownloads: return "Downloads"
        case .screenshots: return "Screenshots"
        case .quickLinks: return "Links"
        default: return title
        }
    }

    /// Icon on a tab (the combined widgets' own icons changed, so their first tab keeps the old one).
    var tabIcon: String {
        switch self {
        case .worldClock: return "globe"
        case .calculator: return "plus.forwardslash.minus"
        case .habits: return "checkmark.seal.fill"
        case .recentClips: return "doc.on.clipboard.fill"
        default: return icon
        }
    }

    /// Someone who turned on a widget that's now a tab gets the combined widget instead. Runs at launch.
    static func migrateMergedWidgets() {
        for kind in allCases {
            guard let parent = kind.mergedInto, kind.isAvailable else { continue }
            if !parent.isAvailable { parent.install() }
            UserDefaults.standard.set(false, forKey: kind.installedKey)
        }
    }

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

    /// True while a widget you type into (Notes) is open: the pointer leaving
    /// doesn't collapse the shelf, but clicking outside still does.
    static var ignoresHoverOut = false

    func install() {
        UserDefaults.standard.set(true, forKey: installedKey)
        extensionType.setRemoved(false)
        NotificationCenter.default.post(name: .extensionStateChanged, object: extensionType)
        AgentsMonitor.shared.sync()
    }

    func cleanup() {
        switch self {
        case .pomodoro: PomodoroManager.shared.reset()
        case .teleprompter: TeleprompterManager.shared.pause()
        case .appVolume: AppVolumeManager.shared.resetAll()
        case .agents: AgentsMonitor.shared.setEnabled(false)
        case .emojiPicker, .meetings, .obsidian, .systemStats, .upNext, .shortcuts, .notes, .worldClock, .calculator, .dice, .colorPicker, .countdown, .stopwatchWidget, .timers, .habits, .water, .breathe, .network, .recentClips, .recentDownloads, .screenshots, .quickLinks, .passwordGenerator, .dayProgress, .moonPhase, .counter, .monthCalendar: break
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
            if kind.tabs.isEmpty {
                Self.content(for: kind)
            } else {
                WidgetTabsView(parent: kind)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(NotchLayoutConstants.contentEdgeInsets(notchHeight: notchHeight, isExternalWithNotchStyle: isExternalWithNotchStyle))
    }

    @ViewBuilder
    static func content(for kind: NotchWidgetKind) -> some View {
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
            case .agents:
                AgentsNotchView(monitor: AgentsMonitor.shared)
            case .notes:
                QuickNotesNotchView(store: QuickNotesStore.shared)
            case .worldClock:
                WorldClockWidgetView()
            case .calculator:
                CalculatorWidgetView()
            case .dice:
                DiceWidgetView()
            case .colorPicker:
                ColorPickerWidgetView()
            case .countdown:
                CountdownWidgetView()
            case .stopwatchWidget:
                StopwatchWidgetView(manager: StopwatchManager.shared)
            case .timers:
                TimersWidgetView(manager: QuickTimerManager.shared)
            case .habits:
                HabitsWidgetView()
            case .water:
                WaterWidgetView()
            case .breathe:
                BreatheWidgetView()
            case .network:
                NetworkWidgetView()
            case .recentClips:
                RecentClipsWidgetView()
            case .recentDownloads:
                DownloadsWidgetView()
            case .screenshots:
                ScreenshotsWidgetView()
            case .quickLinks:
                QuickLinksWidgetView()
            case .passwordGenerator:
                PasswordWidgetView()
            case .dayProgress:
                DayProgressWidgetView()
            case .moonPhase:
                MoonWidgetView()
            case .counter:
                CounterWidgetView()
            case .monthCalendar:
                MonthWidgetView()
            }
    }
}

/// A combined widget: a row of tabs over the chosen tab's view. Remembers the last tab.
struct WidgetTabsView: View {
    let parent: NotchWidgetKind
    @AppStorage private var selected: String

    init(parent: NotchWidgetKind) {
        self.parent = parent
        _selected = AppStorage(wrappedValue: parent.rawValue, "widgetTab_\(parent.rawValue)")
    }

    var body: some View {
        let current = parent.tabs.first { $0.rawValue == selected } ?? parent
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(parent.tabs) { tab in
                    let on = tab == current
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { selected = tab.rawValue }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: tab.tabIcon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(tab.tabTitle)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(on ? Color.white : Color.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(on ? parent.tint.opacity(0.45) : Color.white.opacity(0.08)))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            NotchWidgetPanel.content(for: current)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .id(current)
        }
    }
}
