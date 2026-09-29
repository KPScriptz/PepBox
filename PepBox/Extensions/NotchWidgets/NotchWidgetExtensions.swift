//
//  NotchWidgetExtensions.swift
//  PepBox
//
//  Extension Store definitions for the notch widgets.
//

import SwiftUI

struct PomodoroExtension: ExtensionDefinition {
    static let id = "pomodoro"
    static let title = "Pomodoro"
    static let subtitle = "Focus timer in your notch"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .red
    static let description = "Work in focused intervals with short and long breaks. Start, pause and skip right from the shelf; a sound plays when each interval ends."
    static let features: [(icon: String, text: String)] = [
        ("timer", "25-minute focus, 5-minute break by default"),
        ("cup.and.saucer.fill", "Long break after every 4 focus sessions"),
        ("bell.fill", "Sound when an interval ends"),
        ("slider.horizontal.3", "Adjust durations in the panel")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "timer"
    static let iconPlaceholderColor: Color = .red
    static func cleanup() { NotchWidgetKind.pomodoro.cleanup() }
}

struct EmojiPickerExtension: ExtensionDefinition {
    static let id = "emojiPicker"
    static let title = "Emoji Picker"
    static let subtitle = "Emoji one click away"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .yellow
    static let description = "Search every emoji by name and type it into the app you're using, or copy it. Recently used emoji stay at the front."
    static let features: [(icon: String, text: String)] = [
        ("magnifyingglass", "Search by name"),
        ("keyboard", "Types into the frontmost app"),
        ("clock.arrow.circlepath", "Recently used first")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "face.smiling"
    static let iconPlaceholderColor: Color = .yellow
    static func cleanup() {}
}

struct TeleprompterExtension: ExtensionDefinition {
    static let id = "teleprompter"
    static let title = "Teleprompter"
    static let subtitle = "Your script under the camera"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .mint
    static let description = "Scroll your script right below the camera so you keep eye contact on calls and recordings. Adjustable speed and text size."
    static let features: [(icon: String, text: String)] = [
        ("text.alignleft", "Script sits right under the camera"),
        ("play.fill", "Play, pause and restart"),
        ("gauge.with.dots.needle.33percent", "Adjustable speed and text size")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "text.alignleft"
    static let iconPlaceholderColor: Color = .mint
    static func cleanup() { NotchWidgetKind.teleprompter.cleanup() }
}

struct MeetingsExtension: ExtensionDefinition {
    static let id = "meetings"
    static let title = "Meetings"
    static let subtitle = "Zoom, Teams and Meet controls"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .blue
    static let description = "Mute, toggle your camera or leave a Zoom, Microsoft Teams or Google Meet call from the notch without hunting for the window."
    static let features: [(icon: String, text: String)] = [
        ("mic.slash.fill", "Mute and unmute"),
        ("video.slash.fill", "Camera on and off"),
        ("phone.down.fill", "Leave the call")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "video.fill"
    static let iconPlaceholderColor: Color = .blue
    static func cleanup() {}
}

struct AppVolumeExtension: ExtensionDefinition {
    static let id = "appVolume"
    static let title = "App Volume"
    static let subtitle = "Volume slider for each app"
    static let category: ExtensionGroup = .media
    static let categoryColor: Color = .green
    static let description = "Turn one app down (or up to 150%) without touching the others. Apps playing sound appear in the panel; click the percentage to reset. Needs macOS 14.2 and Screen & System Audio Recording permission."
    static let features: [(icon: String, text: String)] = [
        ("speaker.wave.2.fill", "A slider for every app playing sound"),
        ("speaker.plus.fill", "Boost quiet apps up to 150%"),
        ("arrow.uturn.backward", "At 100% the app's audio is left untouched")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "speaker.wave.2.fill"
    static let iconPlaceholderColor: Color = .green
    static func cleanup() { NotchWidgetKind.appVolume.cleanup() }
}

struct ObsidianExtension: ExtensionDefinition {
    static let id = "obsidian"
    static let title = "Obsidian"
    static let subtitle = "Your vault on the shelf"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .purple
    static let description = "Your most recently edited Obsidian notes one click away, with search, plus a capture field that appends a timestamped line to a \"PepBox Inbox\" note in your vault. The vault is found from Obsidian's settings, or pick it yourself."
    static let features: [(icon: String, text: String)] = [
        ("clock.arrow.circlepath", "Recent notes, newest first"),
        ("magnifyingglass", "Find a note by title"),
        ("square.and.pencil", "Quick capture into PepBox Inbox.md")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "note.text"
    static let iconPlaceholderColor: Color = .purple
}

struct SystemStatsExtension: ExtensionDefinition {
    static let id = "systemStats"
    static let title = "System Stats"
    static let subtitle = "CPU, GPU, memory and network"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .teal
    static let description = "CPU, GPU and memory gauges plus live network speed and free disk space, one click from the shelf. Sampled once a second only while the panel is open; no permissions needed."
    static let features: [(icon: String, text: String)] = [
        ("cpu", "CPU and GPU load"),
        ("memorychip", "Memory used, like Activity Monitor"),
        ("arrow.up.arrow.down", "Network down/up speed"),
        ("internaldrive", "Free disk space")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "gauge.with.dots.needle.67percent"
    static let iconPlaceholderColor: Color = .teal
}

struct UpNextExtension: ExtensionDefinition {
    static let id = "upNext"
    static let title = "Up Next"
    static let subtitle = "Weather and your next meetings"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .orange
    static let description = "Today's weather and your next few calendar events side by side, with a Join button for Zoom, Meet, Teams and Webex links. When a meeting is 10 minutes out it shows as a live activity beside the notch. Weather comes from Open-Meteo for a city you type once, so there's no location permission."
    static let features: [(icon: String, text: String)] = [
        ("cloud.sun.fill", "Current weather with today's high and low"),
        ("calendar", "Next events with countdowns"),
        ("video.fill", "One-click Join for meeting links"),
        ("bell.badge", "Live activity before a meeting starts")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "calendar.badge.clock"
    static let iconPlaceholderColor: Color = .orange
}

struct ShortcutsWidgetExtension: ExtensionDefinition {
    static let id = "shortcuts"
    static let title = "Shortcuts"
    static let subtitle = "Run Apple Shortcuts from the shelf"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .indigo
    static let description = "Your favorite Apple Shortcuts one click from the shelf. Pin the ones you use, or drop files on a shortcut to run it with them as input: resize images, convert files, upload, whatever your shortcut does."
    static let features: [(icon: String, text: String)] = [
        ("play.fill", "Run any shortcut with one click"),
        ("pin", "Pin the ones you use most"),
        ("tray.and.arrow.down", "Drop files on a shortcut as its input")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "square.2.layers.3d.fill"
    static let iconPlaceholderColor: Color = .indigo
}

struct AgentsExtension: ExtensionDefinition {
    static let id = "agents"
    static let title = "Agents"
    static let subtitle = "Claude Code and Codex progress in the notch"
    static let category: ExtensionGroup = .ai
    static let categoryColor: Color = .orange
    static let description = "See what your coding agent is doing without switching windows: the current tool call beside the notch (\"Edit Agents.swift\", \"Run xcodebuild\"), a yellow \"Needs you\" when it's waiting for approval, and \"Done\" when the turn ends. The shelf panel adds tool-call and edit counts and the time this turn has taken. Reads the agents' session logs on this Mac only; nothing leaves your computer."
    static let features: [(icon: String, text: String)] = [
        ("sparkle", "Claude Code and Codex, detected automatically"),
        ("hand.raised.fill", "\"Needs you\" when a tool call waits for approval"),
        ("list.bullet", "Recent tool calls, edits and turn time"),
        ("lock.shield", "Local logs only, no network")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "sparkle"
    static let iconPlaceholderColor: Color = .orange
}
