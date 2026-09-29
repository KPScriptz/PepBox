//
//  QuickSearchMath.swift
//  PepBox
//
//  Quick Search's calculator and unit converter. No app dependencies, so
//  scripts/logic-tests compiles and tests it directly.
//

import Foundation

// MARK: - Calculator (safe: no NSExpression, which raises on malformed input)

enum QuickCalculator {
    /// Evaluates + - * / ^ % and parentheses. Returns nil unless the whole input is a valid expression.
    static func evaluate(_ input: String) -> Double? {
        let text = input.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: ",", with: "")
        // Must contain an operator, otherwise a plain number isn't worth showing.
        guard !text.isEmpty, text.rangeOfCharacter(from: CharacterSet(charactersIn: "+-*/^%(")) != nil,
              text.allSatisfy({ "0123456789.+-*/^%()".contains($0) }) else { return nil }
        var parser = Parser(chars: Array(text))
        guard let value = parser.expression(), parser.index == parser.chars.count, value.isFinite else { return nil }
        return value
    }

    static func format(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 { return String(Int64(value)) }
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private struct Parser {
        let chars: [Character]
        var index = 0

        mutating func expression() -> Double? {
            guard var value = term() else { return nil }
            while index < chars.count, chars[index] == "+" || chars[index] == "-" {
                let op = chars[index]; index += 1
                guard let rhs = term() else { return nil }
                value = op == "+" ? value + rhs : value - rhs
            }
            return value
        }

        mutating func term() -> Double? {
            guard var value = power() else { return nil }
            while index < chars.count, "*/%".contains(chars[index]) {
                let op = chars[index]; index += 1
                guard let rhs = power() else { return nil }
                switch op {
                case "*": value *= rhs
                case "/": value /= rhs
                default: value = value.truncatingRemainder(dividingBy: rhs)
                }
            }
            return value
        }

        mutating func power() -> Double? {
            guard let base = unary() else { return nil }
            if index < chars.count, chars[index] == "^" {
                index += 1
                guard let exponent = power() else { return nil }  // right-associative
                return pow(base, exponent)
            }
            return base
        }

        mutating func unary() -> Double? {
            if index < chars.count, chars[index] == "-" {
                index += 1
                return unary().map { -$0 }
            }
            if index < chars.count, chars[index] == "+" {
                index += 1
                return unary()
            }
            return primary()
        }

        mutating func primary() -> Double? {
            guard index < chars.count else { return nil }
            if chars[index] == "(" {
                index += 1
                guard let value = expression(), index < chars.count, chars[index] == ")" else { return nil }
                index += 1
                return value
            }
            let start = index
            while index < chars.count, chars[index].isNumber || chars[index] == "." { index += 1 }
            guard index > start else { return nil }
            return Double(String(chars[start..<index]))
        }
    }
}

// MARK: - Unit conversion ("5 km to mi", "70 f in c")

enum QuickUnitConverter {
    private static let units: [String: Dimension] = [
        // length
        "mm": UnitLength.millimeters, "cm": UnitLength.centimeters, "m": UnitLength.meters,
        "km": UnitLength.kilometers, "in": UnitLength.inches, "inch": UnitLength.inches,
        "inches": UnitLength.inches, "ft": UnitLength.feet, "feet": UnitLength.feet, "foot": UnitLength.feet,
        "yd": UnitLength.yards, "mi": UnitLength.miles, "mile": UnitLength.miles, "miles": UnitLength.miles,
        // mass
        "g": UnitMass.grams, "kg": UnitMass.kilograms, "lb": UnitMass.pounds, "lbs": UnitMass.pounds,
        "oz": UnitMass.ounces, "st": UnitMass.stones,
        // temperature
        "c": UnitTemperature.celsius, "°c": UnitTemperature.celsius, "celsius": UnitTemperature.celsius,
        "f": UnitTemperature.fahrenheit, "°f": UnitTemperature.fahrenheit, "fahrenheit": UnitTemperature.fahrenheit,
        "k": UnitTemperature.kelvin, "kelvin": UnitTemperature.kelvin,
        // volume
        "ml": UnitVolume.milliliters, "l": UnitVolume.liters, "liter": UnitVolume.liters, "liters": UnitVolume.liters,
        "gal": UnitVolume.gallons, "gallon": UnitVolume.gallons, "gallons": UnitVolume.gallons,
        "floz": UnitVolume.fluidOunces, "cup": UnitVolume.cups, "cups": UnitVolume.cups,
        // speed
        "kmh": UnitSpeed.kilometersPerHour, "km/h": UnitSpeed.kilometersPerHour,
        "mph": UnitSpeed.milesPerHour, "m/s": UnitSpeed.metersPerSecond, "knots": UnitSpeed.knots,
        // data
        "kb": UnitInformationStorage.kilobytes, "mb": UnitInformationStorage.megabytes,
        "gb": UnitInformationStorage.gigabytes, "tb": UnitInformationStorage.terabytes
    ]

    static func convert(_ input: String) -> String? {
        let pattern = #"^\s*(-?[\d.,]+)\s*([a-z°/]+)\s+(?:to|in|as)\s+([a-z°/]+)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let lower = input.lowercased()
        let range = NSRange(lower.startIndex..., in: lower)
        guard let match = regex.firstMatch(in: lower, range: range), match.numberOfRanges == 4,
              let valueRange = Range(match.range(at: 1), in: lower),
              let fromRange = Range(match.range(at: 2), in: lower),
              let toRange = Range(match.range(at: 3), in: lower),
              let value = Double(lower[valueRange].replacingOccurrences(of: ",", with: "")),
              let from = units[String(lower[fromRange])],
              let to = units[String(lower[toRange])],
              type(of: from) == type(of: to) else { return nil }
        let converted = Measurement(value: value, unit: from).converted(to: to)
        return "\(QuickCalculator.format((converted.value * 10_000).rounded() / 10_000)) \(lower[toRange])"
    }
}

// MARK: - Currency conversion ("100 usd to eur", "$20 in gbp", "50€ to $")

enum QuickCurrencyConverter {
    private static let symbols: [String: String] = [
        "$": "USD", "€": "EUR", "£": "GBP", "¥": "JPY", "₹": "INR", "₩": "KRW", "₽": "RUB", "₺": "TRY", "₪": "ILS", "฿": "THB",
        "dollar": "USD", "dollars": "USD", "euro": "EUR", "euros": "EUR", "pound": "GBP", "pounds": "GBP", "yen": "JPY"
    ]

    /// Rates are units per 1 USD, as published by open.er-api.com.
    static func convert(_ input: String, rates: [String: Double]) -> String? {
        let pattern = #"^\s*([$€£¥₹₩₽₺₪฿]?)\s*([\d.,]+)\s*([a-z$€£¥₹₩₽₺₪฿]*)\s+(?:to|in|as)\s+([a-z$€£¥₹₩₽₺₪฿]+)\s*$"#
        guard !rates.isEmpty, let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let text = input.lowercased()
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        func group(_ i: Int) -> String { Range(match.range(at: i), in: text).map { String(text[$0]) } ?? "" }

        let prefix = group(1), amountText = group(2), suffix = group(3), target = group(4)
        guard prefix.isEmpty != suffix.isEmpty,  // exactly one source currency
              let amount = Double(amountText.replacingOccurrences(of: ",", with: "")),
              let from = code(prefix.isEmpty ? suffix : prefix, rates: rates),
              let to = code(target, rates: rates), from != to,
              let fromRate = rates[from], let toRate = rates[to], fromRate > 0 else { return nil }
        let value = amount / fromRate * toRate
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US")
        return "\(formatter.string(from: NSNumber(value: value)) ?? String(value)) \(to)"
    }

    private static func code(_ token: String, rates: [String: Double]) -> String? {
        if let mapped = symbols[token] { return mapped }
        let upper = token.uppercased()
        return upper.count == 3 && rates[upper] != nil ? upper : nil
    }
}

/// Exchange rates from open.er-api.com (free, no key), refreshed at most every 12 hours.
enum QuickCurrencyRates {
    private static let ratesKey = "quickSearch_currencyRates"
    private static let fetchedKey = "quickSearch_currencyRatesFetched"

    static var cached: [String: Double] {
        UserDefaults.standard.dictionary(forKey: ratesKey) as? [String: Double] ?? [:]
    }

    static func refreshIfStale() {
        let fetched = UserDefaults.standard.double(forKey: fetchedKey)
        guard Date().timeIntervalSince1970 - fetched > 12 * 3600,
              let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["result"] as? String == "success",
                  let rates = json["rates"] as? [String: NSNumber] else { return }
            UserDefaults.standard.set(rates.mapValues(\.doubleValue), forKey: ratesKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: fetchedKey)
        }.resume()
    }
}

// MARK: - Timers ("timer 5m", "timer 1h30m tea", "25 min timer")

enum QuickTimerParser {
    struct Request: Equatable {
        let seconds: TimeInterval
        let label: String?
    }

    /// Accepts "timer <duration> [label]" or "<duration> timer". A bare number means minutes.
    static func parse(_ input: String) -> Request? {
        let words = input.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard words.count >= 2 else { return nil }
        var rest: [String]
        if words.first == "timer" {
            rest = Array(words.dropFirst())
        } else if words.last == "timer" {
            rest = Array(words.dropLast())
        } else {
            return nil
        }

        // Consume duration tokens from the front ("1h", "30m", "1", "h", "90 sec"); the rest is a label.
        var seconds: TimeInterval = 0
        var consumed = 0
        var pendingNumber: Double?
        let unitPattern = try! NSRegularExpression(pattern: #"^(\d+(?:\.\d+)?)?([a-z]*)$"#)
        tokens: for token in rest {
            for part in splitNumberRuns(token) {
                let range = NSRange(part.startIndex..., in: part)
                guard let match = unitPattern.firstMatch(in: part, range: range) else { break tokens }
                let number = Range(match.range(at: 1), in: part).flatMap { Double(part[$0]) }
                let unit = Range(match.range(at: 2), in: part).map { String(part[$0]) } ?? ""
                if let number, unit.isEmpty {
                    if let pending = pendingNumber { seconds += pending * 60 }
                    pendingNumber = number
                } else if let multiplier = multiplier(for: unit) {
                    guard let value = number ?? pendingNumber else { break tokens }
                    seconds += value * multiplier
                    pendingNumber = nil
                } else {
                    break tokens
                }
            }
            consumed += 1
        }
        if let pending = pendingNumber { seconds += pending * 60 }
        guard seconds >= 1, seconds <= 24 * 3600 else { return nil }
        let label = rest.dropFirst(consumed).joined(separator: " ")
        return Request(seconds: seconds.rounded(), label: label.isEmpty ? nil : label)
    }

    /// "1h30m" → ["1h", "30m"].
    private static func splitNumberRuns(_ token: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inUnit = false
        for character in token {
            let isDigit = character.isNumber || character == "."
            if isDigit && inUnit {
                parts.append(current)
                current = ""
                inUnit = false
            }
            if !isDigit { inUnit = true }
            current.append(character)
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    private static func multiplier(for unit: String) -> TimeInterval? {
        switch unit {
        case "h", "hr", "hrs", "hour", "hours": return 3600
        case "m", "min", "mins", "minute", "minutes": return 60
        case "s", "sec", "secs", "second", "seconds": return 1
        default: return nil
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
