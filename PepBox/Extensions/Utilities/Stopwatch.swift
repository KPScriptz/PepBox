//
//  Stopwatch.swift
//  PepBox
//
//  A stopwatch that counts up beside the notch. Start it from Quick Search
//  ("stopwatch") or the Ring; stopping copies the elapsed time.
//

import AppKit
import SwiftUI

@Observable
final class StopwatchManager {
    static let shared = StopwatchManager()

    private(set) var startDate: Date?
    private(set) var now = Date()
    private var ticker: Timer?

    var isRunning: Bool { startDate != nil }
    var elapsed: TimeInterval { startDate.map { now.timeIntervalSince($0) } ?? 0 }

    func toggle() {
        if isRunning { stop() } else { start() }
    }

    func start() {
        startDate = Date()
        now = Date()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.now = Date() }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    /// Stops and copies the time, e.g. "12:04".
    @discardableResult
    func stop() -> String {
        now = Date()
        let text = Self.format(elapsed)
        ticker?.invalidate()
        ticker = nil
        startDate = nil
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        FlashActivity.shared.show(LiveActivity(id: "stopwatch-\(UUID())", icon: "stopwatch", tint: .mint,
                                               text: "\(text) copied", progress: nil), for: 3)
        return text
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    var liveActivity: LiveActivity? {
        guard isRunning else { return nil }
        return LiveActivity(id: "stopwatch", icon: "stopwatch", tint: .mint, text: Self.format(elapsed), progress: nil)
    }
}
