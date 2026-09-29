//
//  PomodoroNotchView.swift
//  PepBox
//
//  The Pomodoro panel. The timer logic is in Pomodoro.swift, which
//  scripts/logic-tests compiles on its own.
//

import SwiftUI

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

                // Compact so ring + controls fit the shelf's ~390 pt content width.
                HStack(spacing: 4) {
                    minuteStepper(icon: "brain.head.profile", help: "Focus minutes", value: $manager.focusMinutes)
                    minuteStepper(icon: "cup.and.saucer", help: "Break minutes", value: $manager.shortBreakMinutes)
                    minuteStepper(icon: "bed.double", help: "Long break minutes", value: $manager.longBreakMinutes)
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

    private func minuteStepper(icon: String, help: String, value: Binding<Int>) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.55))
            Text("\(value.wrappedValue)m")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .monospacedDigit()
            Stepper("", value: value, in: 1...120)
                .labelsHidden()
                .controlSize(.mini)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(Capsule().fill(.white.opacity(0.08)))
        .help(help)
    }
}
