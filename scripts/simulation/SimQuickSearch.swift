// Scenario: Quick Search fuzzing. Every case runs every parser Quick Search runs on a keystroke.
// Each case is generated from its index alone, so after a crash run.sh resumes at the next index
// and the breadcrumb names the exact input.

import Foundation

private let numbers: [String] = [
    "0", "1", "7", "12", "-1", "-42", "3.5", "0.0000001", "1,000", "1,000,000.50", "1e5", "-0", "00012",
    "99999999999999999999999", String(repeating: "9", count: 400), "9223372036854775807", "9223372036854775808",
    "-9223372036854775808", "1.2.3", "..", ".", "١٢", "٣", "½", "nan", "inf", "0x1F", "1_000", "１２"
]
private let words: [String] = [
    "hello", "world", "tokyo", "new york", "london", "narnia", "est", "pst", "utc", "ist", "kst", "la", "sf",
    "lunch with Sam", "call mom", "mm", "km", "mi", "kg", "lb", "f", "c", "°c", "gb", "mb", "usd", "eur", "jpy", "$", "€", "¥",
    "👨‍👩‍👧‍👦", "🇺🇸", "e\u{301}", "مرحبا بالعالم", "שלום", "日本語", "İstanbul", "Straße", "ﬁle", "\u{200B}", "\u{0}", "\t",
    "%", "%%", "%zz", "%E2%82", "{", "}", "\\", "\"", "'", "<script>", "a&b=c", "#", "@", "~", "/", ":", "MMXXVI", "IIII",
    "eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjF9.x", "eyJ", "aGVsbG8", "====", "ff8800", "#f80", "rgb(1,2,3)"
]
private let templates: [String] = [
    "{n}% of {n}", "tip {n}% of ${n}", "{n} is what % of {n}", "{n} - {n}%", "{n} + {n}%", "{n}px", "{n}rem", "{n} px",
    "split {n} by {n}", "split ${n} {n} ways", "char {n}", "char u+{w}", "code {w}", "unicode {w}{w}", "roman {n}", "{w}",
    "0x{w}", "0b{n}", "0o{n}", "{n} in hex", "{n} to binary", "{n} as octal", "base64 {w}", "base64 decode {w}",
    "unbase64 {w}", "url encode {w} {w}", "url decode {w}", "days until {w}", "days until {n}-{n}-{n}", "days to {w} {n}",
    "today + {n} days", "today - {n} weeks", "in {n} months", "{n} years ago", "{n} days from now", "time in {w}",
    "time {w}", "{n}pm {w} in {w}", "{n}:{n} {w} to {w}", "{n}am {w} to {w}", "timer {n}m {w}", "timer {n}h{n}m",
    "{n} min timer", "timer {n} {w}", "remind {w} in {n}m", "remind me to {w} in {n} {w}", "event {w} tomorrow at {n}pm",
    "meeting {w} {w}", "volume {n}", "vol {n}%", "brightness {n}", "mute", "roll {n}d{n}", "roll d{n}", "password {n}",
    "pw {n}", "lorem {n}", "pick {w}, {w}, {w}", "choose {w}|{w}", "words {w} {w}", "contrast #{w} #{w}", "contrast {w}",
    "jwt {w}", "http {n}", "status {n}", "chmod {n}", "week", "{n} {w} to {w}", "{n} {w} in {w}", "{w}{n} to {w}",
    "{n}*{n}", "({n}+{n})^{n}", "{n}/{n}", "{n}%{n}", "#{w}", "rgb({n},{n},{n})", "rgba({n}, {n}, {n}, {n})", "{n}",
    "{w} {w}", "quit {w}", "{w} settings", "awake {n}", "caffeinate {n}h", "stay awake {n} hours", "port {n}", ":{n}",
    "mail {w}@{w}.{w}", "{w}@{w}.com", "~/{w}", "/{w}/{w}", "yt {w}", "gh {w}", "{w}.com/{w}", "localhost:{n}",
    "{n}.{n}.{n}.{n}:{n}", "https://{w}", "note {w}", "todo {w}", "clocks", "timestamp", "{n}0000000"
]

/// Deterministic input for a case.
func quickSearchInput(_ index: Int) -> String {
    var rng = RNG(UInt64(index) &* 0x5851_F42D_4C95_7F2D &+ 17)
    // Every 97th case is a 10,000-character adversarial paste.
    if index % 97 == 0 {
        let unit = rng.pick(["1" + String(repeating: " ", count: 9_998) + "x",
                             String(repeating: "(", count: 10_000), String(repeating: "-", count: 9_999) + "1",
                             String(repeating: "2^", count: 4_999) + "2", "a@" + String(repeating: ".a", count: 4_999) + "1",
                             "1" + String(repeating: " ", count: 5_000) + "km" + String(repeating: " ", count: 4_000),
                             "3pm " + String(repeating: "a ", count: 4_997) + "in", "event " + String(repeating: " ", count: 9_990) + "x",
                             String(repeating: "👍", count: 10_000), String(repeating: "9", count: 10_000) + "% of 2",
                             "base64 decode " + String(repeating: "QUFB", count: 2_500), "pick " + String(repeating: "a,", count: 5_000),
                             String(repeating: "M", count: 10_000), "remind " + String(repeating: "x in ", count: 2_000) + "5m",
                             "timer " + String(repeating: "1h", count: 5_000), String(repeating: "\u{301}", count: 10_000)])
        return unit
    }
    switch rng.int(10) {
    case 0:   // random scalars
        let pools: [ClosedRange<UInt32>] = [0x20...0x7E, 0x0600...0x06FF, 0x0300...0x036F, 0x1F300...0x1F6FF, 0x4E00...0x4E80, 0x00...0x1F]
        return String(String.UnicodeScalarView((0..<rng.range(0...40)).compactMap { _ in
            let pool = rng.pick(pools)
            return Unicode.Scalar(pool.lowerBound + UInt32(rng.int(Int(pool.upperBound - pool.lowerBound) + 1)))
        }))
    case 1:   // whitespace-only and near-empty
        return rng.pick(["", " ", "   ", "\t", "\n", " \u{00A0} ", "\u{3000}", "x", " 1 "])
    default:
        var text = rng.pick(templates)
        while let range = text.range(of: "{n}") ?? text.range(of: "{w}") {
            text.replaceSubrange(range, with: text[range] == "{n}" ? rng.pick(numbers) : rng.pick(words))
        }
        if rng.chance(0.1) { text = text.uppercased() }
        if rng.chance(0.05) { text = "  " + text + "  " }
        return text
    }
}

private let fixedRates: [String: Double] = ["USD": 1, "EUR": 0.92, "GBP": 0.79, "JPY": 151.3, "CAD": 1.36, "INR": 83.2, "XAU": 0.0004, "ZZZ": 0]
private let appNames = ["Safari", "Slack", "System Settings", "Messages", "Spotify", "Xcode", "Finder", "Notes", "Mail", "Calendar",
                        "1Password", "Visual Studio Code", "Google Chrome", "Zoom.us", "Ölfeld", "日本語アプリ"]

/// Runs every Quick Search parser on one input. Returns the slowest single call (ms) and its name.
@discardableResult
func runQuickSearchCase(_ input: String, now: Date, timeZone: TimeZone, withEvent: Bool) -> (Double, String) {
    var counter: UInt64 = 0
    let random: () -> UInt64 = { counter &+= 0x9E37_79B9; return counter }
    var slowest = (0.0, "")
    func measure(_ name: String, _ block: () -> Void) {
        let ms = timed(block)
        if ms > slowest.0 { slowest = (ms, name) }
    }
    measure("answers") {
        for answer in QuickTools.answers(for: input, now: now, timeZone: timeZone, random: random) {
            check(!answer.title.isEmpty, "empty answer title for \(short(input)) (\(answer.id))")
        }
    }
    measure("devTools") { _ = QuickTools.devTools(input, now: now, random: random) }
    measure("calculator") { if let v = QuickCalculator.evaluate(input) { _ = QuickCalculator.format(v) } }
    measure("units") { _ = QuickUnitConverter.convert(input) }
    measure("currency") { _ = QuickCurrencyConverter.convert(input, rates: fixedRates) }
    measure("timer") { if let r = QuickTimerParser.parse(input) { _ = QuickTimerParser.format(r.seconds) } }
    measure("commands") { _ = QuickCommand.matches(input, runningApps: appNames.enumerated().map { ($1, pid_t($0 + 100)) }) }
    measure("rankApps") { _ = QuickTools.rankApps(appNames, query: input.trimmingCharacters(in: .whitespaces).lowercased(), usage: ["Slack": 5]) }
    measure("small parsers") {
        _ = QuickTools.levelCommand(input)
        _ = QuickTools.reminder(input)
        _ = QuickTools.typedURL(input)
        _ = QuickTools.webShortcut(input)
        _ = QuickTools.mailto(input)
        _ = QuickTools.typedPath(input, home: "/Users/kp")
        _ = QuickTools.awakeRequest(input)
        _ = QuickTools.portQuery(input)
        _ = QuickTools.argument(input, after: ["note", "todo", "qr"])
        _ = QuickTools.pmsetRemaining(input)
        _ = QuickTools.parseLsof(input)
    }
    if withEvent { measure("eventRequest") { _ = QuickTools.eventRequest(input) } }
    if input.count < 40, ["clocks", "world clock"].contains(input.lowercased()) { _ = QuickTools.worldClocks(now: now) }
    return slowest
}

func scenarioQuickSearchFuzz(start: Int) {
    let total = 30_000
    let zones = ["America/Chicago", "Europe/London", "Asia/Kolkata", "Pacific/Chatham", "Australia/Lord_Howe", "America/St_Johns"]
        .compactMap(TimeZone.init(identifier:))
    var slow: [(Double, String, String)] = []
    var maxMs = 0.0
    for index in start..<total where inShard(index) {
        let input = quickSearchInput(index)
        // Day-by-day clock: 6 months of queries spread over the sim window, any time of day.
        let now = Date(timeIntervalSince1970: 1_790_812_800 + Double(index) * (182 * 86_400 / Double(total)) + Double(index % 86_400))
        Crumb.set(index, input)
        let (ms, name) = runQuickSearchCase(input, now: now, timeZone: zones[index % zones.count], withEvent: index % 10 == 0)
        maxMs = max(maxMs, ms)
        if ms > 50 { slow.append((ms, name, input)) }
        checks += 1
    }
    for (ms, name, input) in slow.sorted(by: { $0.0 > $1.0 }).prefix(8) {
        note(String(format: "slow call %.0f ms in %@ for %@", ms, name, short(input, 70)))
    }
    check(slow.allSatisfy { $0.0 < 3000 }, "a single Quick Search parser took ≥3 s on one input (a frozen UI on that keystroke); see notes")
    note("shard \(shard.index + 1)/\(shard.count): \((start..<total).filter(inShard).count) fuzz inputs (from case \(start)); slowest single call \(String(format: "%.1f", maxMs)) ms; \(slow.count) calls over 50 ms")
}
