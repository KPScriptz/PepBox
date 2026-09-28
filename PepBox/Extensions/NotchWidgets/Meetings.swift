//
//  Meetings.swift
//  PepBox
//
//  Mute, camera and leave controls for Zoom, Microsoft Teams and Google Meet.
//  Each action brings the meeting app (or Meet tab) forward and presses that
//  app's own keyboard shortcut, so it needs Accessibility.
//

import SwiftUI
import AppKit
import Carbon.HIToolbox

@Observable
final class MeetingsManager {
    static let shared = MeetingsManager()

    enum Platform: String, CaseIterable, Identifiable {
        case zoom, teams, meet
        var id: String { rawValue }

        var title: String {
            switch self {
            case .zoom: return "Zoom"
            case .teams: return "Teams"
            case .meet: return "Meet"
            }
        }

        /// Native app bundle IDs (Meet runs in a browser instead).
        var bundleIDs: [String] {
            switch self {
            case .zoom: return ["us.zoom.xos"]
            case .teams: return ["com.microsoft.teams2", "com.microsoft.teams"]
            case .meet: return []
            }
        }
    }

    enum Action {
        case mute, camera, leave
    }

    /// Browsers PepBox can search for a Meet tab: Chromium ones share Chrome's AppleScript.
    private static let chromiumBrowsers = ["com.google.Chrome", "com.brave.Browser", "com.microsoft.edgemac"]
    private static let safari = "com.apple.Safari"

    private(set) var runningPlatforms: [Platform] = []
    private(set) var lastMessage: String?

    private let scriptQueue = DispatchQueue(label: "com.pepbox.meetings.applescript")

    /// Refreshes which platforms could have a call (native app or a supported browser running).
    func refresh() {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        runningPlatforms = Platform.allCases.filter { platform in
            switch platform {
            case .zoom, .teams:
                return platform.bundleIDs.contains(where: running.contains)
            case .meet:
                return (Self.chromiumBrowsers + [Self.safari]).contains(where: running.contains)
            }
        }
    }

    func perform(_ action: Action, on platform: Platform) {
        guard AXIsProcessTrusted() else {
            lastMessage = "Needs Accessibility"
            PermissionManager.shared.requestAccessibilityForUserAction()
            return
        }
        lastMessage = nil

        switch platform {
        case .zoom, .teams:
            let running = NSWorkspace.shared.runningApplications
            guard let app = running.first(where: { platform.bundleIDs.contains($0.bundleIdentifier ?? "") }) else {
                lastMessage = "\(platform.title) isn't running"
                return
            }
            app.activate()
            sendShortcut(for: action, on: platform)
        case .meet:
            scriptQueue.async { [weak self] in
                let found = Self.focusMeetTab()
                DispatchQueue.main.async {
                    guard let self else { return }
                    if found {
                        self.sendShortcut(for: action, on: .meet)
                    } else {
                        self.lastMessage = "No Meet tab found"
                    }
                }
            }
        }
    }

    private func sendShortcut(for action: Action, on platform: Platform) {
        let key: (code: Int, flags: CGEventFlags)
        switch (platform, action) {
        case (.zoom, .mute): key = (kVK_ANSI_A, [.maskCommand, .maskShift])
        case (.zoom, .camera): key = (kVK_ANSI_V, [.maskCommand, .maskShift])
        case (.zoom, .leave): key = (kVK_ANSI_W, [.maskCommand])  // Zoom asks to confirm
        case (.teams, .mute): key = (kVK_ANSI_M, [.maskCommand, .maskShift])
        case (.teams, .camera): key = (kVK_ANSI_O, [.maskCommand, .maskShift])
        case (.teams, .leave): key = (kVK_ANSI_H, [.maskCommand, .maskShift])
        case (.meet, .mute): key = (kVK_ANSI_D, [.maskCommand])
        case (.meet, .camera): key = (kVK_ANSI_E, [.maskCommand])
        case (.meet, .leave): key = (kVK_ANSI_W, [.maskCommand])  // closing the tab leaves the call
        }
        // Let the app come forward before the shortcut arrives.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            for keyDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(key.code), keyDown: keyDown) else { continue }
                event.flags = key.flags
                event.post(tap: .cghidEventTap)
            }
        }
    }

    /// Brings the first Google Meet call tab to the front. Runs AppleScript, so call off the main thread.
    private static func focusMeetTab() -> Bool {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let meetCall = "meet.google.com/"
        for bundleID in chromiumBrowsers where running.contains(bundleID) {
            let source = """
            tell application id "\(bundleID)"
                repeat with w in windows
                    set i to 0
                    repeat with t in tabs of w
                        set i to i + 1
                        if URL of t contains "\(meetCall)" and URL of t does not end with "\(meetCall)" then
                            set active tab index of w to i
                            set index of w to 1
                            activate
                            return "found"
                        end if
                    end repeat
                end repeat
            end tell
            return "none"
            """
            if run(source) == "found" { return true }
        }
        if running.contains(safari) {
            let source = """
            tell application id "\(safari)"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "\(meetCall)" and URL of t does not end with "\(meetCall)" then
                            set current tab of w to t
                            set index of w to 1
                            activate
                            return "found"
                        end if
                    end repeat
                end repeat
            end tell
            return "none"
            """
            if run(source) == "found" { return true }
        }
        return false
    }

    private static func run(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { print("🎥 Meetings: AppleScript error \(error)") }
        return result?.stringValue
    }
}

struct MeetingsNotchView: View {
    var manager: MeetingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if manager.runningPlatforms.isEmpty {
                Text("Open Zoom, Teams or a Google Meet tab to control your call here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                ForEach(manager.runningPlatforms) { platform in
                    HStack(spacing: 10) {
                        Text(platform.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, alignment: .leading)
                        controlButton("mic.slash.fill", help: "Mute / unmute", tint: .orange) {
                            manager.perform(.mute, on: platform)
                        }
                        controlButton("video.slash.fill", help: "Camera on / off", tint: .blue) {
                            manager.perform(.camera, on: platform)
                        }
                        controlButton("phone.down.fill", help: "Leave call", tint: .red) {
                            manager.perform(.leave, on: platform)
                        }
                    }
                }
            }
            if let message = manager.lastMessage {
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .onAppear { manager.refresh() }
    }

    private func controlButton(_ icon: String, help: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
        }
        .buttonStyle(PepBoxCircleButtonStyle(size: 32, solidFill: tint.opacity(0.85)))
        .help(help)
    }
}
