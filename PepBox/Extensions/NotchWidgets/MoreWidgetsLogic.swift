//
//  MoreWidgetsLogic.swift
//  PepBox
//
//  The calculations behind the small shelf widgets (moon, day progress,
//  month grid, countdowns, habits), kept free of UI so they can be tested.
//

import Foundation

enum WidgetMath {
    // MARK: Moon

    struct MoonInfo: Equatable {
        let age: Double            // days since new moon, 0..<29.53
        let illumination: Double   // 0...1
        let name: String
        let symbol: String         // SF Symbol
        let daysToFull: Int
    }

    static let synodicMonth = 29.530588853
    /// A known new moon: 2000-01-06 18:14 UTC.
    private static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440)

    static func moon(on date: Date) -> MoonInfo {
        let days = date.timeIntervalSince(referenceNewMoon) / 86_400
        var age = days.truncatingRemainder(dividingBy: synodicMonth)
        if age < 0 { age += synodicMonth }
        let illumination = (1 - cos(2 * .pi * age / synodicMonth)) / 2
        let phases: [(Double, String, String)] = [
            (1.84566, "New Moon", "moonphase.new.moon"),
            (5.53699, "Waxing Crescent", "moonphase.waxing.crescent"),
            (9.22831, "First Quarter", "moonphase.first.quarter"),
            (12.91963, "Waxing Gibbous", "moonphase.waxing.gibbous"),
            (16.61096, "Full Moon", "moonphase.full.moon"),
            (20.30228, "Waning Gibbous", "moonphase.waning.gibbous"),
            (23.99361, "Last Quarter", "moonphase.last.quarter"),
            (27.68493, "Waning Crescent", "moonphase.waning.crescent"),
            (synodicMonth + 1, "New Moon", "moonphase.new.moon")
        ]
        let phase = phases.first { age < $0.0 } ?? phases[0]
        let full = synodicMonth / 2
        let untilFull = age <= full ? full - age : synodicMonth - age + full
        return MoonInfo(age: age, illumination: illumination, name: phase.1, symbol: phase.2, daysToFull: Int(untilFull.rounded()))
    }

    // MARK: Day progress

    /// How far through the day, week, month and year `now` is (0...1 each).
    static func progress(now: Date, calendar: Calendar = .current) -> (day: Double, week: Double, month: Double, year: Double) {
        func fraction(_ component: Calendar.Component) -> Double {
            guard let interval = calendar.dateInterval(of: component, for: now), interval.duration > 0 else { return 0 }
            return min(1, max(0, now.timeIntervalSince(interval.start) / interval.duration))
        }
        return (fraction(.day), fraction(.weekOfYear), fraction(.month), fraction(.year))
    }

    // MARK: Month grid

    /// Weeks of day numbers for a month view, nil for blank cells; weeks start on the calendar's first weekday.
    static func monthGrid(year: Int, month: Int, calendar: Calendar = .current) -> [[Int?]] {
        guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let days = calendar.range(of: .day, in: .month, for: first)?.count else { return [] }
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [Int?] = Array(repeating: nil, count: leading) + (1...days).map { $0 }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    // MARK: Countdowns

    /// Whole days from today to `date` (negative once it's passed), by calendar day, not 24-hour blocks.
    static func daysUntil(_ date: Date, from now: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }

    // MARK: Habits

    /// Day keys ("2026-09-30") a habit was done → current streak (survives until the end of today).
    static func streak(doneDays: Set<String>, now: Date, calendar: Calendar = .current) -> Int {
        func key(_ date: Date) -> String {
            let p = calendar.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
        }
        var day = calendar.startOfDay(for: now)
        if !doneDays.contains(key(day)) { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        var count = 0
        while doneDays.contains(key(day)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let p = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
    }

    // MARK: Calculator

    /// Applies a calculator key to the display text. "C" clears, "⌫" deletes, "=" evaluates.
    static func calculatorKey(_ key: String, display: String) -> String {
        switch key {
        case "C": return "0"
        case "⌫": return display.count <= 1 ? "0" : String(display.dropLast())
        case "=":
            let expression = display.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/").replacingOccurrences(of: "−", with: "-")
            return QuickCalculator.evaluate(expression).map(QuickCalculator.format) ?? "Error"
        default:
            if display == "0" || display == "Error" { return [".", "+", "×", "÷", "−", "%"].contains(key) ? "0" + key : key }
            return display + key
        }
    }
}
