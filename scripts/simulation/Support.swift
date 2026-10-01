// Shared helpers for the long-run simulation: seeded RNG, checks, crash breadcrumbs,
// a hang watchdog, timing, and an independent calendar/DST reference (no Foundation
// Calendar), so date answers are checked against arithmetic rather than themselves.

import Foundation

// MARK: - Deterministic RNG (SplitMix64)

struct RNG: RandomNumberGenerator {
    var state: UInt64
    init(_ seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 &+ 0x2545_F491_4F6C_DD1D }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func int(_ n: Int) -> Int { n <= 1 ? 0 : Int(next() % UInt64(n)) }
    mutating func range(_ r: ClosedRange<Int>) -> Int { r.lowerBound + int(r.upperBound - r.lowerBound + 1) }
    mutating func chance(_ p: Double) -> Bool { Double(next() % 1_000_000) / 1_000_000 < p }
    mutating func pick<T>(_ items: [T]) -> T { items[int(items.count)] }
    mutating func bytes(_ count: Int) -> Data {
        var data = Data(count: count)
        data.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            var i = 0
            while i < count {
                var v = next()
                for _ in 0..<8 where i < count { raw[i] = UInt8(truncatingIfNeeded: v); v >>= 8; i += 1 }
            }
        }
        return data
    }
    mutating func uuid() -> UUID {
        let b = bytes(16)
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }
}

// MARK: - Checks and reporting

var scenarioName = ""
var checks = 0
var failures = 0
private var printedFailures = 0
var notes: [String] = []

func short(_ value: Any, _ limit: Int = 140) -> String {
    let text = String(describing: value)
    let escaped = text.debugDescription
    return escaped.count > limit ? String(escaped.prefix(limit)) + "…(\(text.count) chars)" : escaped
}

func check(_ ok: Bool, _ label: @autoclosure () -> String) {
    checks += 1
    guard !ok else { return }
    failures += 1
    if printedFailures < 25 {
        printedFailures += 1
        print("FAIL [\(scenarioName)] \(label())")
    } else if printedFailures == 25 {
        printedFailures += 1
        print("FAIL [\(scenarioName)] … further failures in this scenario not printed")
    }
}

func expectEq<T: Equatable>(_ actual: T, _ expected: T, _ label: @autoclosure () -> String) {
    check(actual == expected, "\(label()): got \(short(actual)), expected \(short(expected))")
}

func note(_ text: String) {
    notes.append(text)
    print("NOTE [\(scenarioName)] \(text)")
}

/// Wall-clock milliseconds for a block.
@discardableResult
func timed(_ block: () -> Void) -> Double {
    let start = DispatchTime.now().uptimeNanoseconds
    block()
    return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
}

// MARK: - Crash breadcrumbs (shared memory, survives a trap) and hang watchdog

/// The child writes "scenario<TAB>case<TAB>description" here before each risky call.
/// run.sh reads it when the child dies from a signal or the watchdog fires,
/// reports the input, and restarts the scenario after that case.
enum Crumb {
    private static var base: UnsafeMutableRawPointer?
    private static let size = 16_384
    static var progress: UInt64 = 0   // bumped by every set(); the watchdog watches it

    static func setup() {
        guard let path = ProcessInfo.processInfo.environment["PEPSIM_CRUMB"] else { return }
        let fd = open(path, O_RDWR | O_CREAT | O_TRUNC, 0o644)
        guard fd >= 0, ftruncate(fd, off_t(size)) == 0 else { return }
        let pointer = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0)
        close(fd)
        if pointer != MAP_FAILED { base = pointer }
    }

    static func set(_ caseIndex: Int, _ description: @autoclosure () -> String) {
        progress &+= 1
        guard let base else { return }
        var text = "\(scenarioName)\t\(caseIndex)\t" + short(description(), 2000)
        text = String(text.utf8.prefix(size - 1)) ?? ""
        let bytes = Array(text.utf8)
        bytes.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in base.copyMemory(from: raw.baseAddress!, byteCount: bytes.count) }
        base.storeBytes(of: 0, toByteOffset: bytes.count, as: UInt8.self)
    }

    static func clear() {
        guard let base else { return }
        base.storeBytes(of: 0, as: UInt8.self)
    }

    /// Exits with 124 if no case makes progress for `seconds` (a regex or loop that never returns).
    static func startWatchdog(seconds: Int = 15) {
        Thread.detachNewThread {
            var last = progress
            var stalled = 0
            while true {
                usleep(1_000_000)
                if progress == last { stalled += 1 } else { stalled = 0; last = progress }
                if stalled >= seconds { fflush(stdout); _exit(124) }
            }
        }
    }
}

// MARK: - Resuming after a crash

/// The first case to run; run.sh passes the case after the one that crashed.
var startCase = 0

/// run.sh can split a scenario across processes: PEPSIM_SHARD="k/n" runs every n-th case starting at k.
let shard: (index: Int, count: Int) = {
    let parts = (ProcessInfo.processInfo.environment["PEPSIM_SHARD"] ?? "0/1").split(separator: "/").compactMap { Int($0) }
    return parts.count == 2 && parts[1] > 0 ? (parts[0], parts[1]) : (0, 1)
}()

func inShard(_ caseIndex: Int) -> Bool { caseIndex % shard.count == shard.index }

/// Marks the start of a case and records it as the breadcrumb; false if the case ran before a crash (skip it).
func step(_ index: Int, _ description: @autoclosure () -> String) -> Bool {
    guard index >= startCase else { return false }
    Crumb.set(index, description())
    return true
}

// MARK: - Independent calendar reference (proleptic Gregorian, Hinnant's algorithms)

func daysFromCivil(_ y: Int, _ m: Int, _ d: Int) -> Int {
    let y2 = m <= 2 ? y - 1 : y
    let era = (y2 >= 0 ? y2 : y2 - 399) / 400
    let yoe = y2 - era * 400
    let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146_097 + doe - 719_468
}

func civilFromDays(_ z0: Int) -> (y: Int, m: Int, d: Int) {
    let z = z0 + 719_468
    let era = (z >= 0 ? z : z - 146_096) / 146_097
    let doe = z - era * 146_097
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
    let mp = (5 * doy + 2) / 153
    let d = doy - (153 * mp + 2) / 5 + 1
    let m = mp + (mp < 10 ? 3 : -9)
    return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
}

/// 0 = Sunday … 6 = Saturday.
func weekdayIndex(_ days: Int) -> Int { ((days % 7) + 7 + 4) % 7 }

func isLeap(_ y: Int) -> Bool { (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }
func daysInMonth(_ y: Int, _ m: Int) -> Int { [31, isLeap(y) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1] }

let monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

/// Day number of the n-th (1-based) given weekday in a month; n = -1 means the last one.
func nthWeekday(_ y: Int, _ m: Int, weekday: Int, n: Int) -> Int {
    if n > 0 {
        let first = daysFromCivil(y, m, 1)
        let offset = (weekday - weekdayIndex(first) + 7) % 7
        return first + offset + (n - 1) * 7
    }
    let last = daysFromCivil(y, m, daysInMonth(y, m))
    return last - (weekdayIndex(last) - weekday + 7) % 7
}

enum RefZone: String, CaseIterable {
    case newYork = "America/New_York", chicago = "America/Chicago", denver = "America/Denver",
         losAngeles = "America/Los_Angeles", london = "Europe/London", paris = "Europe/Paris",
         tokyo = "Asia/Tokyo", kolkata = "Asia/Kolkata", utc = "UTC"

    var standardOffset: Int {
        switch self {
        case .newYork: return -5 * 3600
        case .chicago: return -6 * 3600
        case .denver: return -7 * 3600
        case .losAngeles: return -8 * 3600
        case .london, .utc: return 0
        case .paris: return 3600
        case .tokyo: return 9 * 3600
        case .kolkata: return 5 * 3600 + 1800
        }
    }

    /// Seconds east of UTC at a Unix time, from the published US (since 2007) and EU rules.
    func offset(at t: Int) -> Int {
        let std = standardOffset
        let year = civilFromDays(Int((Double(t + std) / 86_400).rounded(.down))).y
        switch self {
        case .newYork, .chicago, .denver, .losAngeles:
            // Second Sunday of March 2:00 standard → first Sunday of November 2:00 daylight.
            let start = nthWeekday(year, 3, weekday: 0, n: 2) * 86_400 + 2 * 3600 - std
            let end = nthWeekday(year, 11, weekday: 0, n: 1) * 86_400 + 2 * 3600 - (std + 3600)
            return t >= start && t < end ? std + 3600 : std
        case .london, .paris:
            // Last Sunday of March 01:00 UTC → last Sunday of October 01:00 UTC.
            let start = nthWeekday(year, 3, weekday: 0, n: -1) * 86_400 + 3600
            let end = nthWeekday(year, 10, weekday: 0, n: -1) * 86_400 + 3600
            return t >= start && t < end ? std + 3600 : std
        case .tokyo, .kolkata, .utc:
            return std
        }
    }

    var abbreviation: (standard: String, daylight: String) {
        switch self {
        case .newYork: return ("EST", "EDT")
        case .chicago: return ("CST", "CDT")
        case .denver: return ("MST", "MDT")
        case .losAngeles: return ("PST", "PDT")
        default: return ("", "")
        }
    }
}

struct LocalTime {
    let days: Int  // days since 1970-01-01 in local time
    let seconds: Int  // seconds into the local day
    var civil: (y: Int, m: Int, d: Int) { civilFromDays(days) }
    var hour: Int { seconds / 3600 }
    var minute: Int { (seconds / 60) % 60 }
    var second: Int { seconds % 60 }
}

func localTime(_ t: Int, _ zone: RefZone) -> LocalTime {
    let local = t + zone.offset(at: t)
    let days = Int((Double(local) / 86_400).rounded(.down))
    return LocalTime(days: days, seconds: local - days * 86_400)
}

/// The Unix time of a local wall-clock time (the earlier one if it's ambiguous; nil if it doesn't exist).
func unixTime(days: Int, seconds: Int, in zone: RefZone) -> Int? {
    let local = days * 86_400 + seconds
    for guess in [zone.standardOffset + 3600, zone.standardOffset] {
        let t = local - guess
        if zone.offset(at: t) == guess { return t }
    }
    return nil
}

/// "h:mm a" in en_US.
func clock12(_ hour: Int, _ minute: Int, second: Int? = nil) -> String {
    let h = hour % 12 == 0 ? 12 : hour % 12
    let s = second.map { String(format: ":%02d", $0) } ?? ""
    return "\(h):\(String(format: "%02d", minute))\(s) \(hour < 12 ? "AM" : "PM")"
}

/// ISO-8601 week number and week-year of a civil day.
func isoWeek(_ days: Int) -> (week: Int, year: Int) {
    let weekday = (weekdayIndex(days) + 6) % 7  // Monday = 0
    let thursday = days - weekday + 3
    let year = civilFromDays(thursday).y
    let firstThursday = nthWeekday(year, 1, weekday: 4, n: 1)
    return ((thursday - firstThursday) / 7 + 1, year)
}
