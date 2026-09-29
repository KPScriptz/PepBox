//
//  Pomodoro.swift
//  PepBox
//
//  Focus timer: focus intervals with short breaks and a long break every few sessions.
//

import SwiftUI
import AppKit

@Observable
final class PomodoroManager {
    static let shared = PomodoroManager()

    enum Phase: String {
        case focus, shortBreak, longBreak

        var title: String {
            switch self {
            case .focus: return "Focus"
            case .shortBreak: return "Break"
            case .longBreak: return "Long Break"
            }
        }

        var tint: Color {
            switch self {
            case .focus: return .red
            case .shortBreak: return .green
            case .longBreak: return .blue
            }
        }
    }

    private enum Keys {
        static let focusMinutes = "pomodoro_focusMinutes"
        static let shortBreakMinutes = "pomodoro_shortBreakMinutes"
        static let longBreakMinutes = "pomodoro_longBreakMinutes"
    }

    /// Focus sessions before a long break.
    let sessionsPerLongBreak = 4

    private(set) var phase: Phase = .focus
    private(set) var isRunning = false
    private(set) var remaining: TimeInterval = 25 * 60
    /// Focus sessions finished since the last long break.
    private(set) var completedFocusSessions = 0

    private var timer: Timer?
    private var endDate: Date?

    var focusMinutes: Int {
        didSet { persist(focusMinutes, key: Keys.focusMinutes, phase: .focus) }
    }

    var shortBreakMinutes: Int {
        didSet { persist(shortBreakMinutes, key: Keys.shortBreakMinutes, phase: .shortBreak) }
    }

    var longBreakMinutes: Int {
        didSet { persist(longBreakMinutes, key: Keys.longBreakMinutes, phase: .longBreak) }
    }

    private init() {
        focusMinutes = Self.storedMinutes(Keys.focusMinutes, default: 25)
        shortBreakMinutes = Self.storedMinutes(Keys.shortBreakMinutes, default: 5)
        longBreakMinutes = Self.storedMinutes(Keys.longBreakMinutes, default: 15)
        remaining = TimeInterval(focusMinutes * 60)
    }

    func duration(of phase: Phase) -> TimeInterval {
        switch phase {
        case .focus: return TimeInterval(focusMinutes * 60)
        case .shortBreak: return TimeInterval(shortBreakMinutes * 60)
        case .longBreak: return TimeInterval(longBreakMinutes * 60)
        }
    }

    /// 0 at the start of the interval, 1 when it ends.
    var progress: Double {
        let total = duration(of: phase)
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / total))
    }

    var formattedRemaining: String {
        let seconds = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning else { return }
        if remaining <= 0 { remaining = duration(of: phase) }
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func pause() {
        guard isRunning else { return }
        tick()
        stopTimer()
    }

    /// Back to a fresh focus interval.
    func reset() {
        stopTimer()
        phase = .focus
        completedFocusSessions = 0
        remaining = duration(of: .focus)
    }

    /// Ends the current interval now and moves to the next one (paused).
    func skip() {
        stopTimer()
        advance()
    }

    func select(_ phase: Phase) {
        stopTimer()
        self.phase = phase
        remaining = duration(of: phase)
    }

    private func tick() {
        guard let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            stopTimer()
            NSSound(named: phase == .focus ? "Glass" : "Hero")?.play()
            advance()
        }
    }

    private func advance() {
        switch phase {
        case .focus:
            completedFocusSessions += 1
            if completedFocusSessions >= sessionsPerLongBreak {
                completedFocusSessions = 0
                phase = .longBreak
            } else {
                phase = .shortBreak
            }
        case .shortBreak, .longBreak:
            phase = .focus
        }
        remaining = duration(of: phase)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        isRunning = false
    }

    private static func storedMinutes(_ key: String, default defaultValue: Int) -> Int {
        let value = UserDefaults.standard.integer(forKey: key)
        return value > 0 ? value : defaultValue
    }

    private func persist(_ minutes: Int, key: String, phase: Phase) {
        UserDefaults.standard.set(minutes, forKey: key)
        // Apply right away when that interval isn't running.
        if self.phase == phase && !isRunning {
            remaining = duration(of: phase)
        }
    }
}
