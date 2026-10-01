//
//  QuickTimers.swift
//  PepBox
//
//  Countdown timers started from Quick Search ("timer 5m tea"). The soonest
//  one shows as a live activity beside the notch; finished timers chime and
//  stay on screen for a few seconds.
//

import SwiftUI
import AppKit

@Observable
final class QuickTimerManager {
    static let shared = QuickTimerManager()

    struct QuickTimer: Identifiable, Equatable {
        let id = UUID()
        let label: String?
        let duration: TimeInterval
        let end: Date

        var title: String { label.map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? "Timer" }
    }

    private(set) var timers: [QuickTimer] = []
    /// A timer that just finished, shown briefly as "Done".
    private(set) var finished: QuickTimer?
    private(set) var now = Date()
    private var ticker: Timer?
    private var finishedAt: Date?

    func start(_ request: QuickTimerParser.Request) {
        timers.append(QuickTimer(label: request.label, duration: request.seconds, end: Date().addingTimeInterval(request.seconds)))
        timers.sort { $0.end < $1.end }
        now = Date()
        startTicking()
    }

    func cancel(_ id: UUID) {
        timers.removeAll { $0.id == id }
        if finished?.id == id { finished = nil }
    }

    func remaining(_ timer: QuickTimer) -> TimeInterval { max(0, timer.end.timeIntervalSince(now)) }

    private func startTicking() {
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        now = Date()
        if let done = timers.first(where: { $0.end <= now }) {
            timers.removeAll { $0.id == done.id }
            finished = done
            finishedAt = now
            chime()
        }
        if let finishedAt, now.timeIntervalSince(finishedAt) > 8 {
            finished = nil
            self.finishedAt = nil
        }
        if timers.isEmpty && finished == nil {
            ticker?.invalidate()
            ticker = nil
        }
    }

    private func chime() {
        let sound = NSSound(named: "Glass")
        sound?.play()
        // Two more rings so it's noticeable from across the room.
        for delay in [1.2, 2.4] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { NSSound(named: "Glass")?.play() }
        }
    }

    /// Live activity for the finished timer, or the next one to finish.
    var liveActivity: LiveActivity? {
        if let finished {
            return LiveActivity(id: "timer-done-\(finished.id)", icon: "bell.fill", tint: .orange,
                                text: "\(finished.title) done", progress: nil)
        }
        guard let next = timers.first else { return nil }
        let left = remaining(next)
        return LiveActivity(id: "timer-\(next.id)", icon: "timer", tint: .orange,
                            text: QuickTimerParser.format(left),
                            progress: next.duration > 0 ? 1 - left / next.duration : nil)
    }
}
