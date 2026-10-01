// Scenarios: Pomodoro focus history over months (and years, to reach pruning), and
// the snippet engine under millions of keystrokes.

import Foundation

// MARK: - Focus history

func scenarioFocus(start: Int) {
    let defaults = UserDefaults.standard
    let keys = ["pomodoro_history", "pomodoro_history_minutes"]
    let saved = keys.map { defaults.object(forKey: $0) }
    defer { for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) } }
    for key in keys { defaults.removeObject(forKey: key) }

    var rng = RNG(0xF0C5)
    let zone = RefZone.chicago   // run.sh pins TZ=America/Chicago; record() uses Calendar.current
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone.rawValue)!
    let firstDay = daysFromCivil(2026, 10, 1)
    var reference: [Int: (sessions: Int, minutes: Int)] = [:]   // civil day → totals
    var maxStored = 0
    let totalDays = 820   // six months of heavy use, then keep going past two years to reach the 400-day prune

    for offset in 0..<totalDays {
        let day = firstDay + offset
        Crumb.set(offset, "focus day \(offset)")
        // Streaky habit: 70% of days, with week-long breaks now and then.
        let active = rng.chance(0.7) && !(offset % 45 >= 38)
        var sessionsToday = active ? rng.range(1...8) : 0
        if offset == 0 { sessionsToday = 1 }
        for _ in 0..<sessionsToday {
            let second = rng.pick([0, 1, 59, 3600 + 1800, 2 * 3600 + 1800, 12 * 3600, 86_399])
            guard let t = unixTime(days: day, seconds: second, in: zone) else { continue }  // inside a DST gap
            let minutes = rng.pick([25, 50, 15, 90, 1])
            FocusHistory.record(minutes: minutes, on: Date(timeIntervalSince1970: TimeInterval(t)))
            reference[day, default: (0, 0)].sessions += 1
            reference[day, default: (0, 0)].minutes += minutes
        }

        // Check at several clock readings during the day.
        for second in [5, 12 * 3600, 86_395] {
            guard let t = unixTime(days: day, seconds: second, in: zone) else { continue }
            let now = Date(timeIntervalSince1970: TimeInterval(t))
            let stored = FocusHistory.sessionsByDay
            // All of the day's sessions are recorded up front, so compare the totals at the day's last reading.
            if second == 86_395 {
                let today = FocusHistory.today(now)
                let ref = reference[day] ?? (0, 0)
                expectEq(today.sessions, ref.sessions, "today sessions day \(offset)")
                expectEq(today.minutes, ref.minutes, "today minutes day \(offset)")
            }
            // Brute-force streak over the reference: back from today (or yesterday if today has none).
            func has(_ d: Int) -> Bool { (reference[d]?.sessions ?? 0) > 0 }
            var cursor = has(day) ? day : day - 1
            var expected = 0
            while has(cursor) { expected += 1; cursor -= 1 }
            // The store forgets days older than a year, so the reference streak is capped the same way only after pruning.
            let actual = FocusHistory.streak(stored, now: now, calendar: calendar)
            if expected <= 366 { expectEq(actual, expected, "streak day \(offset) +\(second)s") }
            maxStored = max(maxStored, stored.count)
        }
        let minutesStored = (UserDefaults.standard.dictionary(forKey: "pomodoro_history_minutes") ?? [:]).count
        check(minutesStored <= FocusHistory.sessionsByDay.count, "minutes dictionary outgrew sessions dictionary on day \(offset)")
    }
    let finalCount = FocusHistory.sessionsByDay.count
    check(maxStored <= 401, "focus history grew to \(maxStored) days (should prune at 400)")
    let bytes = (try? PropertyListSerialization.data(fromPropertyList: FocusHistory.sessionsByDay, format: .binary, options: 0).count) ?? 0
    note("\(totalDays) days simulated; history peaked at \(maxStored) day-keys, ends at \(finalCount) (~\(bytes / 1024) KB in UserDefaults)")
    // Six-month figure for the report.
    note("after 182 days the store would hold ≤182 keys; pruning first triggers on day ~400")
}

// MARK: - Snippet engine

func scenarioSnippets(start: Int) {
    var rng = RNG(0x5A1B)
    let longTrigger = ";" + String(repeating: "long", count: 17)   // 69 characters
    let snippets = [
        Snippet(trigger: ";sig", text: "Kyle\n{date}"), Snippet(trigger: ";addr", text: "123 Main St"),
        Snippet(trigger: ";d", text: "{date}"), Snippet(trigger: "x;d", text: "special"),       // suffix overlap: longer wins
        Snippet(trigger: ";shrug", text: "¯\\_(ツ)_/¯"), Snippet(trigger: "→→", text: "⇒"),
        Snippet(trigger: ";ß", text: "ss"), Snippet(trigger: ";🇺🇸", text: "USA"), Snippet(trigger: "", text: "never"),
        Snippet(trigger: ";e\u{301}", text: "accent"), Snippet(trigger: ";clip", text: "[{clipboard}]"),
        Snippet(trigger: longTrigger, text: "long one")
    ]
    let vocabulary = ["the ", "quick ", "brown ", "fox ", ";si", "g", ";", "d", "x", "→", ";ad", "dr", ";shru", "ß", "🇺", "🇸",
                      "e", "\u{301}", "\n", "  ", "é", ";cl", "ip", longTrigger]
    var engine = SnippetEngine()
    var typed = ""           // reference: everything typed since the last expansion (no length limit)
    var keystrokes = 0, fired = 0, missed: [String: Int] = [:], wrong = 0, maxBuffer = 0
    let keystrokeTarget = 2_000_000
    var caseIndex = 0

    while keystrokes < keystrokeTarget {
        caseIndex += 1
        // A burst of typing: words, with typos fixed by backspace, and occasional caret jumps.
        let piece = rng.pick(vocabulary)
        var stroke: [String] = piece.map(String.init)
        if rng.chance(0.08) { stroke += Array(repeating: "\u{7F}", count: rng.range(1...4)) }
        if rng.chance(0.01) { engine.reset(); typed = "" }
        for key in stroke {
            keystrokes += 1
            let result = engine.type(key, snippets: snippets)
            maxBuffer = max(maxBuffer, engine.buffer.count)
            // Reference: an unlimited buffer; the longest trigger that the typing ends with fires.
            if key == "\u{7F}" { if !typed.isEmpty { typed.removeLast() } } else { typed += key }
            let expected = key == "\u{7F}" ? nil : snippets.filter { !$0.trigger.isEmpty && typed.hasSuffix($0.trigger) }
                .max { $0.trigger.count < $1.trigger.count }
            checks += 1
            if result?.trigger != expected?.trigger {
                if let e = expected, result == nil { missed[e.trigger, default: 0] += 1 } else { wrong += 1 }
                engine.reset()
            }
            if result != nil || expected != nil { typed = "" }
            if result != nil { fired += 1 }
        }
        if caseIndex % 2_000 == 0 { Crumb.set(caseIndex, "snippets after \(keystrokes) keystrokes") }
    }
    check(maxBuffer <= max(64, longTrigger.count), "snippet buffer exceeded its limit (\(maxBuffer))")
    expectEq(wrong, 0, "snippet fired the wrong trigger or fired when nothing was typed")
    for (trigger, count) in missed.sorted(by: { $0.key < $1.key }) {
        check(false, "trigger \(short(trigger, 30)) (\(trigger.count) chars) was typed \(count)× but never expanded")
    }
    // Placeholder expansion: the clipboard is the user's text and must be pasted verbatim.
    let fixed = Date(timeIntervalSince1970: 1_790_776_800)
    let en = Locale(identifier: "en_US")
    for clip in ["{date}", "50% {year} off", "{uuid}", "{{clipboard}}", "{weekday}"] {
        expectEq(SnippetEngine.expand("[{clipboard}]", now: fixed, clipboard: clip, locale: en), "[\(clip)]", "clipboard placeholder pastes \(clip) verbatim")
    }
    expectEq(SnippetEngine.expand("{date} {time} {year}", now: fixed, locale: en).contains("{"), false, "every placeholder expands")
    note("\(keystrokes) keystrokes, \(fired) expansions, buffer peak \(maxBuffer) characters")
}
