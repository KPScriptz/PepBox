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
    static let subtitle = "CPU, GPU, memory, network and battery"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .teal
    static let description = "CPU, GPU and memory gauges plus live network speed and free disk space, one click from the shelf. Sampled once a second only while the panel is open; no permissions needed."
    static let features: [(icon: String, text: String)] = [
        ("cpu", "CPU and GPU load"),
        ("memorychip", "Memory used, like Activity Monitor"),
        ("arrow.up.arrow.down", "Network down/up speed"),
        ("internaldrive", "Free disk space"),
        ("battery.75", "Battery level and charging"),
        ("chart.xyaxis.line", "Last-minute graphs for CPU and memory")
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

struct QuickNotesExtension: ExtensionDefinition {
    static let id = "quickNotes"
    static let title = "Notes"
    static let subtitle = "A notepad on your shelf"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .yellow
    static let description = "Jot something down the moment it crosses your mind, right on the shelf, with no app switch. Notes save as you type and stay until you delete them; right-click a note to copy or delete it."
    static let features: [(icon: String, text: String)] = [
        ("square.and.pencil", "New note in one click"),
        ("arrow.triangle.2.circlepath", "Saves as you type"),
        ("doc.on.doc", "Copy a note's text from its menu")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "note.text.badge.plus"
    static let iconPlaceholderColor: Color = .yellow
}

struct WorldClockWidgetExtension: ExtensionDefinition {
    static let id = "worldClock"
    static let title = "World Clock"
    static let subtitle = "Times around the world"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .cyan
    static let description = "Up to eight cities side by side, updated live. Type a city or an abbreviation like PST to add it; right-click to remove."
    static let features: [(icon: String, text: String)] = [("globe", "Times around the world"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "globe"
    static let iconPlaceholderColor: Color = .cyan
}

struct CalculatorWidgetExtension: ExtensionDefinition {
    static let id = "calculator"
    static let title = "Calculator"
    static let subtitle = "A quick calculator"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .orange
    static let description = "A keypad calculator on the shelf, with percentages and brackets. Copy the result with one click."
    static let features: [(icon: String, text: String)] = [("plus.forwardslash.minus", "A quick calculator"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "plus.forwardslash.minus"
    static let iconPlaceholderColor: Color = .orange
}

struct DiceWidgetExtension: ExtensionDefinition {
    static let id = "dice"
    static let title = "Dice & Coin"
    static let subtitle = "Roll, flip or decide"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .red
    static let description = "Roll a d6, 2d6, d20 or d100, flip a coin, or get a yes or no."
    static let features: [(icon: String, text: String)] = [("dice.fill", "Roll, flip or decide"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "dice.fill"
    static let iconPlaceholderColor: Color = .red
}

struct ColorPickerWidgetExtension: ExtensionDefinition {
    static let id = "colorPicker"
    static let title = "Color Picker"
    static let subtitle = "Pick colors from the screen"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .pink
    static let description = "Pick any color on screen; its hex is copied and kept in a row of your last ten colors to copy again."
    static let features: [(icon: String, text: String)] = [("eyedropper", "Pick colors from the screen"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "eyedropper"
    static let iconPlaceholderColor: Color = .pink
}

struct CountdownWidgetExtension: ExtensionDefinition {
    static let id = "countdown"
    static let title = "Countdown"
    static let subtitle = "Days until what matters"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .purple
    static let description = "Count down to trips, launches and birthdays. Days are calendar days, so it's right across time changes."
    static let features: [(icon: String, text: String)] = [("hourglass", "Days until what matters"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "hourglass"
    static let iconPlaceholderColor: Color = .purple
}

struct StopwatchWidgetWidgetExtension: ExtensionDefinition {
    static let id = "stopwatchWidget"
    static let title = "Stopwatch"
    static let subtitle = "Stopwatch with laps"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .mint
    static let description = "A stopwatch with laps. It keeps counting beside the notch when the shelf is closed, and stopping copies the time."
    static let features: [(icon: String, text: String)] = [("stopwatch", "Stopwatch with laps"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "stopwatch"
    static let iconPlaceholderColor: Color = .mint
}

struct TimersWidgetExtension: ExtensionDefinition {
    static let id = "timers"
    static let title = "Timers"
    static let subtitle = "One-tap timers"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .orange
    static let description = "Start a 1, 3, 5, 10, 15, 25 or 45 minute timer with one tap. Timers count down beside the notch and chime when done."
    static let features: [(icon: String, text: String)] = [("timer", "One-tap timers"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "timer"
    static let iconPlaceholderColor: Color = .orange
}

struct HabitsWidgetExtension: ExtensionDefinition {
    static let id = "habits"
    static let title = "Habits"
    static let subtitle = "Daily check-ins with streaks"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .green
    static let description = "Tick off up to five daily habits and watch the streaks grow."
    static let features: [(icon: String, text: String)] = [("checkmark.seal.fill", "Daily check-ins with streaks"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "checkmark.seal.fill"
    static let iconPlaceholderColor: Color = .green
}

struct WaterWidgetExtension: ExtensionDefinition {
    static let id = "water"
    static let title = "Water"
    static let subtitle = "Track glasses of water"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .cyan
    static let description = "Tap once per glass and see today's progress toward your goal."
    static let features: [(icon: String, text: String)] = [("drop.fill", "Track glasses of water"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "drop.fill"
    static let iconPlaceholderColor: Color = .cyan
}

struct BreatheWidgetExtension: ExtensionDefinition {
    static let id = "breathe"
    static let title = "Breathe"
    static let subtitle = "Guided box breathing"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .teal
    static let description = "A slow animated guide for box breathing: four seconds in, hold, out, hold."
    static let features: [(icon: String, text: String)] = [("wind", "Guided box breathing"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "wind"
    static let iconPlaceholderColor: Color = .teal
}

struct NetworkWidgetExtension: ExtensionDefinition {
    static let id = "network"
    static let title = "Network"
    static let subtitle = "Your IP addresses"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .blue
    static let description = "Your local and public IP and your Mac's name, each one click to copy."
    static let features: [(icon: String, text: String)] = [("network", "Your IP addresses"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "network"
    static let iconPlaceholderColor: Color = .blue
}

struct RecentClipsWidgetExtension: ExtensionDefinition {
    static let id = "recentClips"
    static let title = "Recent Clips"
    static let subtitle = "Your last copies, one click away"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .indigo
    static let description = "Your six most recent text clips on the shelf. Click one to copy it again. Passwords are never shown."
    static let features: [(icon: String, text: String)] = [("doc.on.clipboard.fill", "Your last copies, one click away"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "doc.on.clipboard.fill"
    static let iconPlaceholderColor: Color = .indigo
}

struct RecentDownloadsWidgetExtension: ExtensionDefinition {
    static let id = "recentDownloads"
    static let title = "Downloads"
    static let subtitle = "Your newest downloads"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .blue
    static let description = "Your six newest downloads. Drag one where it needs to go, or double-click to open. macOS asks once for access to your Downloads folder."
    static let features: [(icon: String, text: String)] = [("arrow.down.circle.fill", "Your newest downloads"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "arrow.down.circle.fill"
    static let iconPlaceholderColor: Color = .blue
}

struct ScreenshotsWidgetExtension: ExtensionDefinition {
    static let id = "screenshots"
    static let title = "Screenshots"
    static let subtitle = "Your latest screenshots"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .teal
    static let description = "Your latest screenshots and screen recordings from wherever macOS saves them. Drag one into any app. macOS asks once for access to that folder (usually the Desktop)."
    static let features: [(icon: String, text: String)] = [("camera.viewfinder", "Your latest screenshots"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "camera.viewfinder"
    static let iconPlaceholderColor: Color = .teal
}

struct QuickLinksWidgetExtension: ExtensionDefinition {
    static let id = "quickLinks"
    static let title = "Quick Links"
    static let subtitle = "Websites one click away"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .indigo
    static let description = "Keep up to nine websites one click away. Type a domain to add it; right-click to remove."
    static let features: [(icon: String, text: String)] = [("link", "Websites one click away"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "link"
    static let iconPlaceholderColor: Color = .indigo
}

struct PasswordGeneratorWidgetExtension: ExtensionDefinition {
    static let id = "passwordGenerator"
    static let title = "Password"
    static let subtitle = "Strong passwords on demand"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .yellow
    static let description = "Make a strong password from 8 to 64 characters, generated on your Mac, and copy it in one click."
    static let features: [(icon: String, text: String)] = [("key.fill", "Strong passwords on demand"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "key.fill"
    static let iconPlaceholderColor: Color = .yellow
}

struct DayProgressWidgetExtension: ExtensionDefinition {
    static let id = "dayProgress"
    static let title = "Day Progress"
    static let subtitle = "How far through the day you are"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .orange
    static let description = "Bars for how much of the day, week, month and year has gone by."
    static let features: [(icon: String, text: String)] = [("chart.bar.fill", "How far through the day you are"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "chart.bar.fill"
    static let iconPlaceholderColor: Color = .orange
}

struct MoonPhaseWidgetExtension: ExtensionDefinition {
    static let id = "moonPhase"
    static let title = "Moon"
    static let subtitle = "Tonight's moon phase"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .gray
    static let description = "The moon's phase and brightness tonight, worked out on your Mac, and the days until the next full moon."
    static let features: [(icon: String, text: String)] = [("moon.stars.fill", "Tonight's moon phase"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "moon.stars.fill"
    static let iconPlaceholderColor: Color = .gray
}

struct CounterWidgetExtension: ExtensionDefinition {
    static let id = "counter"
    static let title = "Counter"
    static let subtitle = "A tally counter"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .pink
    static let description = "A big tally counter with a label you can name. It remembers the count."
    static let features: [(icon: String, text: String)] = [("number.circle.fill", "A tally counter"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "number.circle.fill"
    static let iconPlaceholderColor: Color = .pink
}

struct MonthCalendarWidgetExtension: ExtensionDefinition {
    static let id = "monthCalendar"
    static let title = "Month"
    static let subtitle = "A month at a glance"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .red
    static let description = "A month calendar with today highlighted. Flip between months."
    static let features: [(icon: String, text: String)] = [("calendar", "A month at a glance"), ("rectangle.bottomhalf.inset.filled", "Opens from a button under the shelf")]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "calendar"
    static let iconPlaceholderColor: Color = .red
}
