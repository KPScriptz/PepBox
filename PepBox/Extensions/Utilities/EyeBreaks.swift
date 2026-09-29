//
//  EyeBreaks.swift
//  PepBox
//
//  The 20-20-20 rule: after 20 minutes of screen time, look at something
//  20 feet away for 20 seconds. The break shows as a live activity beside
//  the notch. Time away from the keyboard counts as a break.
//

import SwiftUI
import AppKit
import CoreGraphics

@Observable
final class EyeBreakManager {
    static let shared = EyeBreakManager()

    static let workMinutesKey = "eyeBreaks_workMinutes"
    static let soundKey = "eyeBreaks_sound"

    /// Seconds left in the current break, or nil while working.
    private(set) var breakRemaining: Int?
    static let breakLength = 20

    private var activeSeconds: TimeInterval = 0
    private var lastTick = Date()
    private var timer: Timer?

    var workInterval: TimeInterval {
        let minutes = UserDefaults.standard.integer(forKey: Self.workMinutesKey)
        return TimeInterval(minutes > 0 ? minutes : 20) * 60
    }

    func setEnabled(_ enabled: Bool) {
        timer?.invalidate()
        timer = nil
        breakRemaining = nil
        activeSeconds = 0
        guard enabled else { return }
        lastTick = Date()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func skipBreak() {
        breakRemaining = nil
        activeSeconds = 0
    }

    private func tick() {
        let now = Date()
        let elapsed = min(now.timeIntervalSince(lastTick), 5)  // sleep/wake shouldn't count as screen time
        lastTick = now

        if let remaining = breakRemaining {
            breakRemaining = remaining > 1 ? remaining - 1 : nil
            if breakRemaining == nil {
                activeSeconds = 0
                if UserDefaults.standard.object(forKey: Self.soundKey) as? Bool ?? true { NSSound(named: "Tink")?.play() }
            }
            return
        }

        let idle = Self.secondsSinceInput()
        if idle >= 120 {
            // Away long enough to rest the eyes already.
            activeSeconds = 0
            return
        }
        activeSeconds += elapsed
        if activeSeconds >= workInterval, !Self.isScreenLocked {
            breakRemaining = Self.breakLength
            if UserDefaults.standard.object(forKey: Self.soundKey) as? Bool ?? true { NSSound(named: "Glass")?.play() }
        }
    }

    static func secondsSinceInput() -> TimeInterval {
        guard let anyEvent = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyEvent)
    }

    private static var isScreenLocked: Bool {
        (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool ?? false
    }
}

struct EyeBreaksExtension: ExtensionDefinition {
    static let id = "eyeBreaks"
    static let title = "Eye Breaks"
    static let subtitle = "20-20-20 reminders in the notch"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .green
    static let description = "Every 20 minutes of screen time, the notch counts down a 20-second break: look at something about 20 feet away. Stepping away from the keyboard for two minutes counts as a break, so it never nags you when you just got back."
    static let features: [(icon: String, text: String)] = [
        ("eye", "20-second break every 20 minutes"),
        ("figure.walk", "Time away resets the timer"),
        ("slider.horizontal.3", "Interval and sound in Options")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "eye"
    static let iconPlaceholderColor: Color = .green
    static func cleanup() { UtilityExtensionKind.eyeBreaks.cleanup() }
}
