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
