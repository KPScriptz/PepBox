// Scenario: date and time answers on every day of the six months (plus DST, month-end,
// leap-day and New Year edge days), at awkward times of day, in several home time zones,
// all checked against the independent calendar/DST arithmetic in Support.swift.

import Foundation

/// Civil days to test: 2026-10-01 + 0…181, plus the transition/edge days around them.
func simulationDays() -> [Int] {
    let start = daysFromCivil(2026, 10, 1)
    var days = Array(start..<(start + 182))
    let extras: [(Int, Int, Int)] = [
        (2026, 3, 7), (2026, 3, 8), (2026, 3, 9), (2026, 3, 28), (2026, 3, 29), (2026, 3, 30),
        (2026, 10, 24), (2026, 10, 25), (2026, 10, 26), (2026, 10, 31), (2026, 11, 1), (2026, 11, 2),
        (2027, 3, 13), (2027, 3, 14), (2027, 3, 15), (2027, 3, 27), (2027, 3, 28), (2027, 3, 29),
        (2027, 12, 26), (2027, 12, 27), (2027, 12, 31), (2028, 1, 1), (2028, 1, 2), (2028, 1, 3),
        (2028, 2, 27), (2028, 2, 28), (2028, 2, 29), (2028, 3, 1), (2028, 12, 31), (2029, 1, 1),
        (2026, 2, 28), (2026, 3, 1), (2027, 2, 28), (2027, 3, 1), (2026, 1, 31), (2026, 4, 30), (2026, 5, 31)
    ]
    days += extras.map { daysFromCivil($0.0, $0.1, $0.2) }
    return Array(Set(days)).sorted()
}

private func firstTitle(_ q: String, _ now: Date, _ zone: TimeZone) -> String? {
    QuickTools.answers(for: q, now: now, timeZone: zone, random: { 4 }).first?.title
}

func scenarioDates(start: Int) {
    let homeZones: [RefZone] = [.chicago, .london, .kolkata, .newYork]
    // Seconds into the local day: just after midnight, inside the DST gap/overlap hours, noon, last minute.
    let timesOfDay = [30, 3600 + 1800, 2 * 3600 + 1800, 3 * 3600 + 1800, 12 * 3600, 23 * 3600 + 59 * 60 + 30]
    let named: [(String, Int, Int)] = [("christmas", 12, 25), ("new year", 1, 1), ("halloween", 10, 31), ("valentines", 2, 14),
                                       ("dec 31", 12, 31), ("jan 1", 1, 1), ("feb 28", 2, 28), ("feb 29", 2, 29), ("mar 1", 3, 1),
                                       ("11/1", 11, 1), ("march 8", 3, 8)]
    var caseIndex = 0
    var sampled = 0
    // Ordinary days get two home zones at three times of day; DST, month-end, leap and New Year days get everything.
    let windowStart = daysFromCivil(2026, 10, 1)
    let edgeDays = Set(simulationDays().filter { day in
        let c = civilFromDays(day)
        return !(windowStart..<(windowStart + 182)).contains(day) || c.d == 1 || c.d == daysInMonth(c.y, c.m)
            || [(2026, 10, 25), (2026, 10, 26), (2026, 11, 1), (2026, 11, 2), (2027, 3, 14), (2027, 3, 15), (2027, 3, 28), (2027, 3, 29)].contains { $0 == (c.y, c.m, c.d) }
    })

    for day in simulationDays() {
        let edge = edgeDays.contains(day)
        for home in edge ? homeZones : [.chicago, homeZones[1 + day % 3]] {
            let tz = TimeZone(identifier: home.rawValue)!
            for secondOfDay in edge ? timesOfDay : [timesOfDay[day % 2 == 0 ? 0 : 5], timesOfDay[2], timesOfDay[4]] {
                guard let t = unixTime(days: day, seconds: secondOfDay, in: home) else { continue }  // skipped by a DST gap
                caseIndex += 1
                if caseIndex < start || !inShard(caseIndex) { continue }
                sampled += 1
                let now = Date(timeIntervalSince1970: TimeInterval(t))
                let local = localTime(t, home)
                let (y, m, d) = local.civil
                let label = "\(home.rawValue) \(y)-\(m)-\(d) +\(secondOfDay)s"
                Crumb.set(caseIndex, label)

                // Days until a named / month-day target (the next one on or after today).
                for (text, tm, td) in named {
                    var target: Int?
                    for year in y...(y + 8) where td <= daysInMonth(year, tm) {
                        let candidate = daysFromCivil(year, tm, td)
                        if candidate >= local.days { target = candidate; break }
                    }
                    guard let target else { continue }
                    let diff = target - local.days
                    let expected = diff == 0 ? "Today" : "\(diff) day\(diff == 1 ? "" : "s")"
                    expectEq(firstTitle("days until \(text)", now, tz), expected, "days until \(text) @ \(label)")
                }
                // Absolute date in the past and future.
                for (ty, tm, td) in [(2027, 1, 1), (2026, 9, 1), (2028, 2, 29)] {
                    let diff = daysFromCivil(ty, tm, td) - local.days
                    let expected = diff == 0 ? "Today" : diff > 0 ? "\(diff) day\(diff == 1 ? "" : "s")" : "\(-diff) day\(diff == -1 ? "" : "s") ago"
                    expectEq(firstTitle(String(format: "days until %04d-%02d-%02d", ty, tm, td), now, tz), expected, "days until \(ty)-\(tm)-\(td) @ \(label)")
                }

                // Offsets: "today + 30 days", "in 2 weeks", "3 months ago", "1 year from now".
                func dayTitle(_ days: Int) -> String {
                    let c = civilFromDays(days)
                    return "\(weekdayNames[weekdayIndex(days)]), \(monthNames[c.m - 1]) \(c.d), \(c.y)"
                }
                func addMonths(_ months: Int) -> Int {
                    let total = y * 12 + (m - 1) + months
                    let ny = Int((Double(total) / 12).rounded(.down)), nm = total - ny * 12 + 1
                    return daysFromCivil(ny, nm, min(d, daysInMonth(ny, nm)))
                }
                expectEq(firstTitle("today + 30 days", now, tz), dayTitle(local.days + 30), "today + 30 days @ \(label)")
                expectEq(firstTitle("today - 1 day", now, tz), dayTitle(local.days - 1), "today - 1 day @ \(label)")
                expectEq(firstTitle("in 2 weeks", now, tz), dayTitle(local.days + 14), "in 2 weeks @ \(label)")
                expectEq(firstTitle("3 months ago", now, tz), dayTitle(addMonths(-3)), "3 months ago @ \(label)")
                expectEq(firstTitle("in 1 month", now, tz), dayTitle(addMonths(1)), "in 1 month @ \(label)")
                expectEq(firstTitle("1 year from now", now, tz), dayTitle(addMonths(12)), "1 year from now @ \(label)")

                // Time-zone conversions use today's date in the source zone.
                func convert(_ hour: Int, _ minute: Int, from: RefZone, to: RefZone) -> String? {
                    let fromDay = localTime(t, from).days
                    guard let instant = unixTime(days: fromDay, seconds: hour * 3600 + minute * 60, in: from) else { return nil }
                    let out = localTime(instant, to)
                    return "\(clock12(out.hour, out.minute)), \(String(weekdayNames[weekdayIndex(out.days)].prefix(3)))"
                }
                for (query, hour, minute, from, to, toLabel) in [
                    ("3pm est in pst", 15, 0, RefZone.newYork, RefZone.losAngeles, "PST"),
                    ("3pm est in london", 15, 0, .newYork, .london, "London"),
                    ("9am pst to paris", 9, 0, .losAngeles, .paris, "Paris"),
                    ("11pm cst in tokyo", 23, 0, .chicago, .tokyo, "Tokyo"),
                    ("12am est in pst", 0, 0, .newYork, .losAngeles, "PST"),
                    ("15:30 london to new york", 15, 30, .london, .newYork, "New York"),
                    ("1:30am cst to utc", 1, 30, .chicago, .utc, "UTC"),
                    ("2:30am est in pst", 2, 30, .newYork, .losAngeles, "PST")
                ] {
                    guard let value = convert(hour, minute, from: from, to: to) else { continue }  // wall time doesn't exist today
                    expectEq(firstTitle(query, now, tz), "\(value) in \(toLabel)", "\(query) @ \(label)")
                }
                for (query, zone, zoneLabel) in [("time in tokyo", RefZone.tokyo, "Tokyo"), ("time in london", .london, "London"),
                                                 ("time in pst", .losAngeles, "PST"), ("time in kolkata", .kolkata, "Kolkata")] {
                    let lt = localTime(t, zone)
                    let expected = "\(clock12(lt.hour, lt.minute)), \(String(weekdayNames[weekdayIndex(lt.days)].prefix(3))) in \(zoneLabel)"
                    expectEq(firstTitle(query, now, tz), expected, "\(query) @ \(label)")
                }

                // Unix timestamps shown in the user's zone (abbreviation rules for US zones).
                if home == .chicago || home == .newYork {
                    let lt = localTime(t, home)
                    let isDST = home.offset(at: t) != home.standardOffset
                    let c = lt.civil
                    let expected = "\(String(weekdayNames[weekdayIndex(lt.days)].prefix(3))), \(String(monthNames[c.m - 1].prefix(3))) \(c.d), \(c.y) at \(clock12(lt.hour, lt.minute, second: lt.second)) \(isDST ? home.abbreviation.daylight : home.abbreviation.standard)"
                    expectEq(firstTitle(String(t), now, tz), expected, "unix \(t) @ \(label)")
                    expectEq(firstTitle(String(t) + "000", now, tz), expected, "unix ms \(t) @ \(label)")
                    expectEq(firstTitle("timestamp", now, tz), String(t), "timestamp now @ \(label)")
                }

                // Things that read the system zone (run.sh sets TZ=America/Chicago).
                if home == .chicago {
                    let week = isoWeek(local.days)
                    expectEq(QuickTools.devTools("week", now: now).first?.title, "Week \(week.week)", "ISO week @ \(label)")
                    expectEq(QuickTools.devTools("week", now: now).first?.subtitle.hasPrefix("ISO week of \(week.year)"), true, "ISO week-year @ \(label)")
                    let en = Locale(identifier: "en_US")
                    let c = local.civil
                    expectEq(SnippetEngine.expand("{date}|{weekday}|{year}", now: now, locale: en),
                             "\(String(monthNames[c.m - 1].prefix(3))) \(c.d), \(c.y)|\(weekdayNames[weekdayIndex(local.days)])|\(c.y)",
                             "snippet date placeholders @ \(label)")
                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = tz
                    expectEq(FocusHistory.dayKey(now, calendar: calendar), String(format: "%04d-%02d-%02d", c.y, c.m, c.d), "focus day key @ \(label)")
                }
            }
        }
    }
    note("shard \(shard.index + 1)/\(shard.count): \(sampled) clock readings (of \(caseIndex)) over \(simulationDays().count) days (\(edgeDays.count) edge days in every zone at 6 times; others 2 zones × 3 times)")
}
