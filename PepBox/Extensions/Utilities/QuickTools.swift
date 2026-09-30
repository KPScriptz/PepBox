//
//  QuickTools.swift
//  PepBox
//
//  Small answers Quick Search can compute on its own: colors, time zones,
//  dates, number bases, percentages, encodings, timestamps and generators.
//  Everything here is pure (the clock and randomness are passed in) so it
//  can be tested; Enter copies the answer.
//

import Foundation

struct QuickAnswer: Equatable {
    let id: String
    let title: String
    let subtitle: String
    let copy: String
    let symbol: String
}

enum QuickTools {
    /// Every tool's answers for a query, most specific first.
    static func answers(for input: String, now: Date = Date(), timeZone: TimeZone = .current,
                        random: () -> UInt64 = { UInt64.random(in: .min ... .max) }) -> [QuickAnswer] {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return [] }
        var results: [QuickAnswer] = []
        results += color(text)
        results += timeZones(text, now: now, local: timeZone)
        results += dates(text, now: now, timeZone: timeZone)
        results += bases(text)
        results += percent(text)
        results += timestamp(text, now: now, timeZone: timeZone)
        results += encodings(text)
        results += generators(text, random: random)
        return results
    }

    // MARK: Colors: "#ff8800", "ff8800", "rgb(255, 136, 0)"

    static func color(_ text: String) -> [QuickAnswer] {
        let lower = text.lowercased().replacingOccurrences(of: " ", with: "")
        var rgb: (Int, Int, Int)?
        if let hex = lower.range(of: #"^#?([0-9a-f]{6}|[0-9a-f]{3})$"#, options: .regularExpression).map({ String(lower[$0]) }) {
            var digits = hex.replacingOccurrences(of: "#", with: "")
            // A bare 3-letter word like "add" or "bad" isn't a color unless it has the #.
            if digits.count == 3 && !hex.hasPrefix("#") { return [] }
            if !hex.hasPrefix("#") && (digits.hasPrefix("0b") || digits.hasPrefix("0x")) { return [] }  // numbers, see bases()
            // Without #, only accept mixed letters and digits ("ff8800"), not words ("facade") or numbers ("123456").
            if digits.count == 6 && !hex.hasPrefix("#") && (digits.allSatisfy(\.isLetter) || digits.allSatisfy(\.isNumber)) { return [] }
            if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
            let value = Int(digits, radix: 16) ?? 0
            rgb = ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
        } else if let match = lower.range(of: #"^rgba?\((\d{1,3}),(\d{1,3}),(\d{1,3})"#, options: .regularExpression) {
            let numbers = lower[match].components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
            if numbers.count >= 3, numbers.prefix(3).allSatisfy({ $0 <= 255 }) { rgb = (numbers[0], numbers[1], numbers[2]) }
        }
        guard let (r, g, b) = rgb else { return [] }
        let hex = String(format: "#%02X%02X%02X", r, g, b)
        let (h, s, l) = hsl(r, g, b)
        let rgbText = "rgb(\(r), \(g), \(b))"
        let hslText = "hsl(\(h), \(s)%, \(l)%)"
        return [
            QuickAnswer(id: "color-hex", title: hex, subtitle: "Hex · Enter to copy", copy: hex, symbol: "paintpalette.fill"),
            QuickAnswer(id: "color-rgb", title: rgbText, subtitle: "RGB · Enter to copy", copy: rgbText, symbol: "paintpalette.fill"),
            QuickAnswer(id: "color-hsl", title: hslText, subtitle: "HSL · Enter to copy", copy: hslText, symbol: "paintpalette.fill")
        ]
    }

    static func hsl(_ r: Int, _ g: Int, _ b: Int) -> (Int, Int, Int) {
        let rf = Double(r) / 255, gf = Double(g) / 255, bf = Double(b) / 255
        let maxV = max(rf, gf, bf), minV = min(rf, gf, bf)
        let l = (maxV + minV) / 2
        guard maxV != minV else { return (0, 0, Int((l * 100).rounded())) }
        let d = maxV - minV
        let s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV)
        var h: Double
        switch maxV {
        case rf: h = (gf - bf) / d + (gf < bf ? 6 : 0)
        case gf: h = (bf - rf) / d + 2
        default: h = (rf - gf) / d + 4
        }
        h *= 60
        return (Int(h.rounded()) % 360, Int((s * 100).rounded()), Int((l * 100).rounded()))
    }

    // MARK: Time zones: "time in tokyo", "3pm est in pst", "15:30 london to new york"

    private static let abbreviations: [String: String] = [
        "est": "America/New_York", "edt": "America/New_York", "et": "America/New_York",
        "cst": "America/Chicago", "cdt": "America/Chicago", "ct": "America/Chicago",
        "mst": "America/Denver", "mdt": "America/Denver", "mt": "America/Denver",
        "pst": "America/Los_Angeles", "pdt": "America/Los_Angeles", "pt": "America/Los_Angeles",
        "utc": "UTC", "gmt": "GMT", "bst": "Europe/London", "cet": "Europe/Paris", "cest": "Europe/Paris",
        "ist": "Asia/Kolkata", "jst": "Asia/Tokyo", "aest": "Australia/Sydney", "kst": "Asia/Seoul",
        "nyc": "America/New_York", "la": "America/Los_Angeles", "sf": "America/Los_Angeles",
        "dallas": "America/Chicago", "houston": "America/Chicago", "miami": "America/New_York",
        "boston": "America/New_York", "seattle": "America/Los_Angeles", "atlanta": "America/New_York",
        "beijing": "Asia/Shanghai", "delhi": "Asia/Kolkata", "mumbai": "Asia/Kolkata", "dubai": "Asia/Dubai"
    ]

    static func zone(named name: String) -> TimeZone? {
        let key = name.lowercased().trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        if let id = abbreviations[key] { return TimeZone(identifier: id) }
        let underscored = key.replacingOccurrences(of: " ", with: "_")
        if let id = TimeZone.knownTimeZoneIdentifiers.first(where: { $0.lowercased().split(separator: "/").last.map(String.init) == underscored }) {
            return TimeZone(identifier: id)
        }
        return nil
    }

    private static func zoneLabel(_ zone: TimeZone, _ name: String) -> String {
        let city = zone.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? name
        return name.count <= 4 ? name.uppercased() : city
    }

    static func timeZones(_ text: String, now: Date, local: TimeZone) -> [QuickAnswer] {
        let lower = text.lowercased()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "h:mm a, EEE"

        if lower.hasPrefix("time in ") || lower.hasPrefix("time ") {
            let name = String(lower.dropFirst(lower.hasPrefix("time in ") ? 8 : 5))
            guard let zone = zone(named: name) else { return [] }
            formatter.timeZone = zone
            let value = formatter.string(from: now)
            return [QuickAnswer(id: "tz-now", title: "\(value) in \(zoneLabel(zone, name))", subtitle: "Time zone · Enter to copy",
                                copy: value, symbol: "globe")]
        }

        // "<time> <zone> in|to <zone>"
        guard let match = lower.range(of: #"^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s+(.+?)\s+(?:in|to)\s+(.+)$"#, options: .regularExpression) else { return [] }
        let parts = try? NSRegularExpression(pattern: #"^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s+(.+?)\s+(?:in|to)\s+(.+)$"#)
            .firstMatch(in: String(lower[match]), range: NSRange(location: 0, length: lower.utf16.count))
        func group(_ i: Int) -> String? {
            guard let range = parts?.range(at: i), range.location != NSNotFound, let r = Range(range, in: lower) else { return nil }
            return String(lower[r])
        }
        guard var hour = group(1).flatMap(Int.init), let fromName = group(4), let toName = group(5),
              let from = zone(named: fromName), let to = zone(named: toName) else { return [] }
        let minute = group(2).flatMap(Int.init) ?? 0
        if let meridiem = group(3) {
            guard (1...12).contains(hour) else { return [] }
            hour = hour % 12 + (meridiem == "pm" ? 12 : 0)
        }
        guard hour < 24, minute < 60 else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = from
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        guard let date = calendar.date(from: components) else { return [] }
        formatter.timeZone = to
        let value = formatter.string(from: date)
        return [QuickAnswer(id: "tz-convert", title: "\(value) in \(zoneLabel(to, toName))",
                            subtitle: "\(text) · Enter to copy", copy: value, symbol: "globe")]
    }

    // MARK: Dates: "days until dec 25", "today + 30 days", "in 2 weeks", "30 days ago"

    static func dates(_ text: String, now: Date, timeZone: TimeZone) -> [QuickAnswer] {
        let lower = text.lowercased()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US")
        output.timeZone = timeZone
        output.dateFormat = "EEEE, MMMM d, yyyy"

        if lower.hasPrefix("days until ") || lower.hasPrefix("days to ") {
            let target = String(lower.drop(while: { $0 != " " }).dropFirst().drop(while: { $0 != " " }).dropFirst())
            guard let date = parseDay(target, now: now, calendar: calendar) else { return [] }
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
            let title = days == 0 ? "Today" : days > 0 ? "\(days) day\(days == 1 ? "" : "s")" : "\(-days) day\(days == -1 ? "" : "s") ago"
            return [QuickAnswer(id: "days-until", title: title, subtitle: "Until \(output.string(from: date)) · Enter to copy",
                                copy: "\(days)", symbol: "calendar")]
        }

        // Offsets.
        let pattern = #"^(?:(?:today|now)\s*([+-])\s*|in\s+)?(\d+)\s*(day|days|week|weeks|month|months|year|years)(\s+ago|\s+from\s+(?:now|today))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: lower, range: NSRange(location: 0, length: lower.utf16.count)) else { return [] }
        func group(_ i: Int) -> String? {
            guard match.range(at: i).location != NSNotFound, let r = Range(match.range(at: i), in: lower) else { return nil }
            return String(lower[r])
        }
        let hasPrefix = lower.hasPrefix("today") || lower.hasPrefix("now") || lower.hasPrefix("in ")
        let suffix = group(4)
        guard hasPrefix || suffix != nil, let amount = group(2).flatMap(Int.init), let unitText = group(3) else { return [] }
        let sign = (group(1) == "-" || suffix?.contains("ago") == true) ? -1 : 1
        let unit: Calendar.Component = unitText.hasPrefix("day") ? .day : unitText.hasPrefix("week") ? .weekOfYear
            : unitText.hasPrefix("month") ? .month : .year
        guard let date = calendar.date(byAdding: unit, value: sign * amount, to: now) else { return [] }
        let value = output.string(from: date)
        return [QuickAnswer(id: "date-offset", title: value, subtitle: "\(text) · Enter to copy", copy: value, symbol: "calendar")]
    }

    static func parseDay(_ text: String, now: Date, calendar: Calendar) -> Date? {
        let named: [String: (Int, Int)] = ["christmas": (12, 25), "new year": (1, 1), "new years": (1, 1),
                                           "halloween": (10, 31), "valentines": (2, 14), "valentine's day": (2, 14)]
        let year = calendar.component(.year, from: now)
        func upcoming(_ month: Int, _ day: Int) -> Date? {
            guard let thisYear = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
            return thisYear < calendar.startOfDay(for: now) ? calendar.date(from: DateComponents(year: year + 1, month: month, day: day)) : thisYear
        }
        let key = text.trimmingCharacters(in: .whitespaces)
        if let (m, d) = named[key] { return upcoming(m, d) }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = calendar.timeZone
        for format in ["yyyy-MM-dd", "MMM d yyyy", "MMMM d yyyy", "MMM d, yyyy", "MMMM d, yyyy", "M/d/yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: key) { return date }
        }
        for format in ["MMM d", "MMMM d", "M/d"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: key) {
                let parts = calendar.dateComponents([.month, .day], from: date)
                return upcoming(parts.month ?? 1, parts.day ?? 1)
            }
        }
        return nil
    }

    // MARK: Number bases: "0xff", "0b1010", "255 in hex", "255 to binary"

    static func bases(_ text: String) -> [QuickAnswer] {
        let lower = text.lowercased().replacingOccurrences(of: "_", with: "")
        var value: Int?
        var targets = ["dec", "hex", "bin"]
        if lower.hasPrefix("0x"), let v = Int(lower.dropFirst(2), radix: 16) { value = v; targets = ["dec", "bin"] }
        else if lower.hasPrefix("0b"), let v = Int(lower.dropFirst(2), radix: 2) { value = v; targets = ["dec", "hex"] }
        else if lower.hasPrefix("0o"), let v = Int(lower.dropFirst(2), radix: 8) { value = v; targets = ["dec", "hex"] }
        else if let match = lower.range(of: #"^\d+\s+(?:in|to|as)\s+(hex|hexadecimal|binary|bin|octal|oct)$"#, options: .regularExpression) {
            let words = lower[match].split(separator: " ")
            value = Int(words[0])
            let target = String(words.last!)
            targets = [target.hasPrefix("hex") ? "hex" : target.hasPrefix("bin") ? "bin" : "oct"]
        }
        guard let value, value >= 0 else { return [] }
        return targets.map { target in
            let (text, name): (String, String)
            switch target {
            case "hex": (text, name) = ("0x" + String(value, radix: 16).uppercased(), "Hexadecimal")
            case "bin": (text, name) = ("0b" + String(value, radix: 2), "Binary")
            case "oct": (text, name) = ("0o" + String(value, radix: 8), "Octal")
            default: (text, name) = (String(value), "Decimal")
            }
            return QuickAnswer(id: "base-\(target)", title: text, subtitle: "\(name) · Enter to copy", copy: text, symbol: "number")
        }
    }

    // MARK: Percentages: "15% of 80", "tip 20% of 64.50", "30 is what % of 120", "80 - 15%"

    static func percent(_ text: String) -> [QuickAnswer] {
        let lower = text.lowercased().replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "$", with: "")
        func number(_ s: Substring) -> Double? { Double(s.trimmingCharacters(in: .whitespaces)) }
        func format(_ v: Double) -> String {
            let rounded = (v * 100).rounded() / 100
            return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.2f", rounded)
        }

        if let match = lower.range(of: #"^(tip\s+)?([\d.]+)\s*%\s*of\s+([\d.]+)$"#, options: .regularExpression) {
            let body = lower[match]
            let isTip = body.hasPrefix("tip")
            let numbers = body.replacingOccurrences(of: "tip", with: "").components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
                .compactMap(Double.init)
            guard numbers.count == 2 else { return [] }
            let part = numbers[0] / 100 * numbers[1]
            var answers = [QuickAnswer(id: "percent-of", title: format(part), subtitle: "\(text) · Enter to copy", copy: format(part), symbol: "percent")]
            if isTip {
                answers.append(QuickAnswer(id: "percent-total", title: "Total \(format(numbers[1] + part))",
                                           subtitle: "Bill plus tip · Enter to copy", copy: format(numbers[1] + part), symbol: "percent"))
            }
            return answers
        }
        if let match = lower.range(of: #"^([\d.]+)\s+is\s+what\s*%\s*of\s+([\d.]+)$"#, options: .regularExpression) {
            let numbers = lower[match].components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).compactMap(Double.init)
            guard numbers.count == 2, numbers[1] != 0 else { return [] }
            let value = format(numbers[0] / numbers[1] * 100) + "%"
            return [QuickAnswer(id: "percent-what", title: value, subtitle: "\(text) · Enter to copy", copy: value, symbol: "percent")]
        }
        if let match = lower.range(of: #"^([\d.]+)\s*([+-])\s*([\d.]+)\s*%$"#, options: .regularExpression) {
            let body = String(lower[match])
            let sign: Double = body.contains("-") ? -1 : 1
            let numbers = body.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).compactMap(Double.init)
            guard numbers.count == 2 else { return [] }
            let value = format(numbers[0] * (1 + sign * numbers[1] / 100))
            return [QuickAnswer(id: "percent-change", title: value, subtitle: "\(text) · Enter to copy", copy: value, symbol: "percent")]
        }
        return []
    }

    // MARK: Unix timestamps: "1790640151", "1790640151000", "timestamp" / "now unix"

    static func timestamp(_ text: String, now: Date, timeZone: TimeZone) -> [QuickAnswer] {
        let lower = text.lowercased()
        if ["timestamp", "unix", "epoch", "now unix", "unix time"].contains(lower) {
            let value = String(Int(now.timeIntervalSince1970))
            return [QuickAnswer(id: "unix-now", title: value, subtitle: "Unix time now · Enter to copy", copy: value, symbol: "clock")]
        }
        // 10-digit seconds or 13-digit milliseconds within a sensible range (2001–2100).
        guard lower.allSatisfy(\.isNumber), lower.count == 10 || lower.count == 13, var seconds = Double(lower) else { return [] }
        if lower.count == 13 { seconds /= 1000 }
        guard seconds > 978_307_200, seconds < 4_102_444_800 else { return [] }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE, MMM d, yyyy 'at' h:mm:ss a zzz"
        let value = formatter.string(from: Date(timeIntervalSince1970: seconds))
        return [QuickAnswer(id: "unix-date", title: value, subtitle: "Unix timestamp · Enter to copy", copy: value, symbol: "clock")]
    }

    // MARK: Encodings: "base64 hello", "base64 decode aGVsbG8=", "url encode a b", "url decode a%20b"

    static func encodings(_ text: String) -> [QuickAnswer] {
        let lower = text.lowercased()
        func answer(_ id: String, _ value: String, _ name: String) -> [QuickAnswer] {
            [QuickAnswer(id: id, title: value, subtitle: "\(name) · Enter to copy", copy: value, symbol: "chevron.left.forwardslash.chevron.right")]
        }
        if lower.hasPrefix("base64 decode ") || lower.hasPrefix("unbase64 ") {
            let payload = String(text.drop(while: { $0 != " " }).dropFirst()).replacingOccurrences(of: "decode ", with: "", options: .anchored)
            var padded = payload.trimmingCharacters(in: .whitespaces)
            while padded.count % 4 != 0 { padded += "=" }
            guard let data = Data(base64Encoded: padded), let decoded = String(data: data, encoding: .utf8) else { return [] }
            return answer("b64-decode", decoded, "Base64 decoded")
        }
        if lower.hasPrefix("base64 ") {
            let payload = String(text.dropFirst(7))
            return answer("b64-encode", Data(payload.utf8).base64EncodedString(), "Base64")
        }
        if lower.hasPrefix("url encode ") {
            let payload = String(text.dropFirst(11))
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            guard let encoded = payload.addingPercentEncoding(withAllowedCharacters: allowed) else { return [] }
            return answer("url-encode", encoded, "URL encoded")
        }
        if lower.hasPrefix("url decode ") {
            guard let decoded = String(text.dropFirst(11)).removingPercentEncoding else { return [] }
            return answer("url-decode", decoded, "URL decoded")
        }
        return []
    }

    // MARK: Generators: "uuid", "password" / "password 24", "lorem 2", "roll d20", "flip"

    static func generators(_ text: String, random: () -> UInt64) -> [QuickAnswer] {
        let words = text.lowercased().split(separator: " ").map(String.init)
        guard let first = words.first else { return [] }
        func pick(_ upper: Int) -> Int { Int(random() % UInt64(upper)) }

        switch first {
        case "uuid", "guid":
            var bytes = (0..<16).map { _ in UInt8(truncatingIfNeeded: random()) }
            bytes[6] = (bytes[6] & 0x0F) | 0x40
            bytes[8] = (bytes[8] & 0x3F) | 0x80
            let uuid = UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                                   bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])).uuidString
            return [QuickAnswer(id: "uuid", title: uuid, subtitle: "New UUID · Enter to copy", copy: uuid, symbol: "number.square")]
        case "password", "pw", "passwd":
            let length = words.count > 1 ? min(max(Int(words[1]) ?? 20, 8), 128) : 20
            let sets = ["abcdefghijkmnopqrstuvwxyz", "ABCDEFGHJKLMNPQRSTUVWXYZ", "23456789", "!@#$%^&*-_=+?"].map(Array.init)
            let all = sets.flatMap { $0 }
            // At least one of each kind, then shuffle.
            var characters = sets.map { $0[pick($0.count)] } + (0..<(length - sets.count)).map { _ in all[pick(all.count)] }
            for index in characters.indices.reversed() where index > 0 {
                characters.swapAt(index, pick(index + 1))
            }
            let password = String(characters)
            return [QuickAnswer(id: "password", title: password, subtitle: "\(length)-character password · made on this Mac · Enter to copy",
                                copy: password, symbol: "key.fill")]
        case "lorem", "ipsum":
            let count = words.count > 1 ? min(max(Int(words[1]) ?? 1, 1), 10) : 1
            let paragraph = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
            let value = Array(repeating: paragraph, count: count).joined(separator: "\n\n")
            return [QuickAnswer(id: "lorem", title: "Lorem ipsum · \(count) paragraph\(count == 1 ? "" : "s")",
                                subtitle: "Placeholder text · Enter to copy", copy: value, symbol: "text.alignleft")]
        case "roll":
            let spec = words.count > 1 ? words[1] : "d6"
            guard let match = spec.range(of: #"^(\d*)d(\d+)$"#, options: .regularExpression) else { return [] }
            let parts = spec[match].split(separator: "d", omittingEmptySubsequences: false)
            let dice = min(max(Int(parts[0]) ?? 1, 1), 20), sides = Int(parts[1]) ?? 6
            guard (2...1000).contains(sides) else { return [] }
            let rolls = (0..<dice).map { _ in pick(sides) + 1 }
            let total = rolls.reduce(0, +)
            let detail = dice > 1 ? " (\(rolls.map(String.init).joined(separator: " + ")))" : ""
            return [QuickAnswer(id: "roll", title: "🎲 \(total)\(detail)", subtitle: "Rolled \(dice)d\(sides) · Enter to copy",
                                copy: String(total), symbol: "dice.fill")]
        case "flip", "coin":
            let side = pick(2) == 0 ? "Heads" : "Tails"
            return [QuickAnswer(id: "flip", title: "🪙 \(side)", subtitle: "Coin flip · Enter to copy", copy: side, symbol: "circle.lefthalf.filled")]
        default:
            return []
        }
    }
}

// MARK: - Parsers used by Quick Search's system lookups

extension QuickTools {
    enum AwakeRequest: Equatable {
        case indefinite
        case minutes(Int)
        case off
    }

    /// "awake", "awake 1h", "awake 90m", "awake 2 hours", "awake off", "caffeinate 30".
    static func awakeRequest(_ text: String) -> AwakeRequest? {
        let words = text.lowercased().split(separator: " ").map(String.init)
        guard let first = words.first, ["awake", "caffeinate", "stay awake"].contains(first) || (first == "stay" && words.dropFirst().first == "awake") else { return nil }
        let rest = words.drop(while: { ["awake", "caffeinate", "stay"].contains($0) }).joined()
        if rest.isEmpty || rest == "on" { return .indefinite }
        if ["off", "stop", "no"].contains(rest) { return .off }
        guard let match = rest.range(of: #"^(\d+)(h|hr|hrs|hour|hours|m|min|mins|minute|minutes)?$"#, options: .regularExpression) else { return nil }
        let token = String(rest[match])
        let number = Int(token.prefix(while: \.isNumber)) ?? 0
        let unit = token.drop(while: \.isNumber)
        let minutes = unit.hasPrefix("h") ? number * 60 : number
        return (1...(24 * 60)).contains(minutes) ? .minutes(minutes) : nil
    }

    /// Port from "port 3000" / ":3000".
    static func portQuery(_ text: String) -> Int? {
        let lower = text.lowercased()
        let digits = lower.hasPrefix("port ") ? String(lower.dropFirst(5)) : lower.hasPrefix(":") ? String(lower.dropFirst()) : ""
        guard let port = Int(digits.trimmingCharacters(in: .whitespaces)), (1...65535).contains(port) else { return nil }
        return port
    }

    /// Parses `lsof -F pcn` output into (pid, command) pairs, one per process.
    static func parseLsof(_ output: String) -> [(pid: Int32, command: String)] {
        var results: [(Int32, String)] = []
        var pid: Int32?
        for line in output.split(separator: "\n") {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())
            if tag == "p" { pid = Int32(value) }
            if tag == "c", let current = pid, !results.contains(where: { $0.0 == current }) { results.append((current, value)) }
        }
        return results
    }
}

extension QuickTools {
    /// "remind stretch in 20m", "remind me to call mom in 1h 30m" → a labelled timer.
    static func reminder(_ text: String) -> QuickTimerParser.Request? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        let labelStart = lower.index(lower.startIndex, offsetBy: 7, limitedBy: lower.endIndex) ?? lower.endIndex
        guard lower.hasPrefix("remind "), let inRange = lower.range(of: " in ", options: .backwards),
              inRange.lowerBound > labelStart else { return nil }
        var label = String(lower[labelStart..<inRange.lowerBound])
        for filler in ["me to ", "me ", "to "] where label.hasPrefix(filler) { label.removeFirst(filler.count) }
        let label2 = label.trimmingCharacters(in: .whitespaces)
        guard !label2.isEmpty,
              let request = QuickTimerParser.parse("timer " + lower[inRange.upperBound...]),
              request.label == nil else { return nil }
        return QuickTimerParser.Request(seconds: request.seconds, label: label2)
    }

    /// The text after a command word: "note buy milk" → "buy milk" for "note".
    static func argument(_ text: String, after commands: [String]) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        for command in commands {
            let prefix = command + " "
            if trimmed.lowercased().hasPrefix(prefix) {
                let rest = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                return rest.isEmpty ? nil : rest
            }
        }
        return nil
    }
}

extension QuickTools {
    /// "2:35" from `pmset -g batt` ("…; 2:35 remaining present: true"); nil while calculating or on AC.
    static func pmsetRemaining(_ output: String) -> String? {
        guard let range = output.range(of: #"\d{1,2}:\d{2} remaining"#, options: .regularExpression) else { return nil }
        let time = output[range].replacingOccurrences(of: " remaining", with: "")
        return time == "0:00" ? nil : time
    }
}
