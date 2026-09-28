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

struct PomodoroNotchView: View {
    @Bindable var manager: PomodoroManager

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: manager.progress)
                    .stroke(manager.phase.tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: manager.progress)
                VStack(spacing: 2) {
                    Text(manager.formattedRemaining)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(manager.phase.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white)
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button { manager.toggle() } label: {
                        Image(systemName: manager.isRunning ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(PepBoxCircleButtonStyle(size: 36, solidFill: manager.phase.tint))
                    .help(manager.isRunning ? "Pause" : "Start")

                    Button { manager.skip() } label: {
                        Image(systemName: "forward.end.fill")
                    }
                    .buttonStyle(PepBoxCircleButtonStyle(size: 36))
                    .help("Skip to next interval")

                    Button { manager.reset() } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(PepBoxCircleButtonStyle(size: 36))
                    .help("Reset")
                }

                HStack(spacing: 6) {
                    minuteStepper("Focus", value: $manager.focusMinutes)
                    minuteStepper("Break", value: $manager.shortBreakMinutes)
                    minuteStepper("Long", value: $manager.longBreakMinutes)
                }

                HStack(spacing: 4) {
                    ForEach(0..<manager.sessionsPerLongBreak, id: \.self) { index in
                        Circle()
                            .fill(index < manager.completedFocusSessions ? Color.red : .white.opacity(0.18))
                            .frame(width: 6, height: 6)
                    }
                    Text("until long break")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func minuteStepper(_ label: String, value: Binding<Int>) -> some View {
        HStack(spacing: 2) {
            Text("\(label) \(value.wrappedValue)m")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .monospacedDigit()
            Stepper("", value: value, in: 1...120)
                .labelsHidden()
                .controlSize(.mini)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(.white.opacity(0.08)))
    }
}
