//
//  LiveActivity.swift
//  PepBox
//
//  Ongoing activities shown beside the closed notch (icon + progress on the
//  left wing, status on the right), like Droppy's Live Activities.
//

import SwiftUI

struct LiveActivity: Equatable {
    let id: String
    let icon: String
    let tint: Color
    let text: String
    /// 0...1, or nil for no progress ring.
    let progress: Double?

    static let enabledKey = "liveActivitiesEnabled"

    /// The activity to show now, if any. Checked in priority order.
    static var current: LiveActivity? {
        guard UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true else { return nil }

        if let flash = FlashActivity.shared.activity { return flash }

        if UtilityExtensionKind.eyeBreaks.isAvailable, let remaining = EyeBreakManager.shared.breakRemaining {
            return LiveActivity(
                id: "eyeBreak",
                icon: "eye",
                tint: .green,
                text: "Look away \(remaining)s",
                progress: 1 - Double(remaining) / Double(EyeBreakManager.breakLength)
            )
        }

        if UtilityExtensionKind.quickSearch.isAvailable, let timer = QuickTimerManager.shared.liveActivity {
            return timer
        }

        if NotchWidgetKind.agents.isAvailable, let agent = AgentsMonitor.shared.liveActivity {
            return agent
        }

        let downloads = DownloadsWatcher.shared
        if UtilityExtensionKind.downloadsActivity.isAvailable, let active = downloads.active, let text = downloads.activityText {
            return LiveActivity(
                id: "download-\(active.name)",
                icon: "arrow.down",
                tint: .blue,
                text: text,
                progress: active.progress
            )
        }

        let pomodoro = PomodoroManager.shared
        if NotchWidgetKind.pomodoro.isAvailable, pomodoro.isRunning {
            return LiveActivity(
                id: "pomodoro",
                icon: pomodoro.phase == .focus ? "timer" : "cup.and.saucer.fill",
                tint: pomodoro.phase.tint,
                text: pomodoro.formattedRemaining,
                progress: pomodoro.progress
            )
        }

        if NotchWidgetKind.upNext.isAvailable, let meeting = UpNextCalendar.shared.imminentEvent {
            let calendar = UpNextCalendar.shared
            let untilStart = meeting.start.timeIntervalSince(calendar.now)
            return LiveActivity(
                id: "upNext-\(meeting.id)",
                icon: meeting.joinURL == nil ? "calendar" : "video.fill",
                tint: .orange,
                text: UpNextCalendar.relative(meeting.start, from: calendar.now),
                progress: max(0, min(1, 1 - untilStart / 600))
            )
        }
        return nil
    }
}

/// Wing layout for a live activity, matching HighAlertHUDView's geometry.
struct LiveActivityHUDView: View {
    let activity: LiveActivity
    let hudWidth: CGFloat
    var targetScreen: NSScreen? = nil
    var notchWidth: CGFloat = 180

    private var layout: HUDLayoutCalculator {
        HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first)
    }

    var body: some View {
        let iconSize = layout.iconSize
        let padding = layout.symmetricPadding(for: iconSize)

        Group {
            if layout.isDynamicIslandMode {
                HStack {
                    icon(size: iconSize, adjusted: true)
                    Spacer()
                    status(adjusted: true)
                }
                .padding(.horizontal, padding)
            } else {
                let wingWidth = (hudWidth - notchWidth) / 2
                HStack(spacing: 0) {
                    HStack {
                        icon(size: iconSize, adjusted: false)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, padding)
                    .frame(width: wingWidth)

                    Spacer().frame(width: notchWidth)

                    HStack {
                        Spacer(minLength: 0)
                        status(adjusted: false)
                    }
                    .padding(.trailing, padding)
                    .frame(width: wingWidth)
                }
            }
        }
        .frame(height: layout.notchHeight)
        .animation(PepBoxAnimation.notchState, value: activity.text)
    }

    private func color(_ adjusted: Bool) -> Color {
        adjusted ? layout.adjustedColor(activity.tint) : activity.tint
    }

    private func icon(size: CGFloat, adjusted: Bool) -> some View {
        ZStack {
            if let progress = activity.progress {
                Circle()
                    .stroke(color(adjusted).opacity(0.25), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color(adjusted), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Image(systemName: activity.icon)
                .font(.system(size: size * 0.62, weight: .semibold))
                .foregroundStyle(color(adjusted))
        }
        .frame(width: size + 4, height: size + 4)
    }

    private func status(adjusted: Bool) -> some View {
        Text(activity.text)
            .font(.system(size: layout.labelFontSize, weight: .semibold, design: .monospaced))
            .foregroundStyle(color(adjusted))
            .contentTransition(.numericText())
            .monospacedDigit()
            .fixedSize()
    }
}
