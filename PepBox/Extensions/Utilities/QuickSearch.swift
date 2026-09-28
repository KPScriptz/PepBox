//
//  QuickSearch.swift
//  PepBox
//
//  A search bar (⌃⌥Space) for apps, files, math and unit conversion.
//

import SwiftUI
import AppKit
import Carbon.HIToolbox

// MARK: - Results

struct QuickSearchResult: Identifiable {
    enum Kind {
        case app(URL)
        case file(URL)
        case answer(String)  // math or conversion; Enter copies it
    }

    let id: String
    let title: String
    let subtitle: String
    let kind: Kind

    var icon: NSImage? {
        switch kind {
        case .app(let url), .file(let url):
            return NSWorkspace.shared.icon(forFile: url.path)
        case .answer:
            return nil
        }
    }
}

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

// MARK: - Search

@Observable
final class QuickSearchModel {
    var query = "" {
        didSet { search() }
    }
    private(set) var results: [QuickSearchResult] = []
    var selection = 0

    private var apps: [URL] = []
    private var fileResults: [QuickSearchResult] = []
    private var fileQuery: NSMetadataQuery?
    private var fileQueryObserver: NSObjectProtocol?

    func prepare() {
        query = ""
        selection = 0
        apps = Self.installedApps()
    }

    private func search() {
        selection = 0
        let text = query.trimmingCharacters(in: .whitespaces)
        var list: [QuickSearchResult] = []
        guard !text.isEmpty else {
            results = []
            stopFileQuery()
            return
        }

        if let value = QuickCalculator.evaluate(text) {
            let answer = QuickCalculator.format(value)
            list.append(QuickSearchResult(id: "math", title: answer, subtitle: "= \(text) · Enter to copy", kind: .answer(answer)))
        }
        if let converted = QuickUnitConverter.convert(text) {
            list.append(QuickSearchResult(id: "unit", title: converted, subtitle: "\(text) · Enter to copy", kind: .answer(converted)))
        }

        let lower = text.lowercased()
        let matchingApps = apps
            .map { ($0, $0.deletingPathExtension().lastPathComponent) }
            .filter { $0.1.lowercased().contains(lower) }
            .sorted { lhs, rhs in
                // Prefix matches first, then shorter names.
                let lp = lhs.1.lowercased().hasPrefix(lower), rp = rhs.1.lowercased().hasPrefix(lower)
                return lp != rp ? lp : lhs.1.count < rhs.1.count
            }
            .prefix(6)
        list += matchingApps.map { url, name in
            QuickSearchResult(id: url.path, title: name, subtitle: "Application", kind: .app(url))
        }

        results = list
        startFileQuery(for: text)
    }

    private func startFileQuery(for text: String) {
        stopFileQuery()
        guard text.count >= 2 else { return }
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "kMDItemDisplayName LIKE[cd] %@ AND kMDItemContentType != 'com.apple.application-bundle'", "*\(text)*")
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        query.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false)]
        fileQueryObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main
        ) { [weak self] notification in
            self?.fileQueryFinished(notification)
        }
        query.start()
        fileQuery = query
    }

    private func fileQueryFinished(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery, query === fileQuery else { return }
        query.disableUpdates()
        let items = (0..<min(query.resultCount, 8)).compactMap { query.result(at: $0) as? NSMetadataItem }
        let files = items.compactMap { item -> QuickSearchResult? in
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { return nil }
            let url = URL(fileURLWithPath: path)
            let folder = (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
            return QuickSearchResult(id: path, title: url.lastPathComponent, subtitle: folder, kind: .file(url))
        }
        let nonFiles = results.filter { if case .file = $0.kind { return false } else { return true } }
        results = nonFiles + files
        stopFileQuery()
    }

    private func stopFileQuery() {
        guard let fileQuery else { return }
        fileQuery.stop()
        if let fileQueryObserver { NotificationCenter.default.removeObserver(fileQueryObserver) }
        fileQueryObserver = nil
        self.fileQuery = nil
    }

    func moveSelection(_ delta: Int) {
        guard !results.isEmpty else { return }
        selection = (selection + delta + results.count) % results.count
    }

    /// Opens the selected result (apps/files) or copies it (answers). Returns true if handled.
    @discardableResult
    func activate(_ result: QuickSearchResult? = nil, revealInFinder: Bool = false) -> Bool {
        guard let result = result ?? (results.indices.contains(selection) ? results[selection] : nil) else { return false }
        switch result.kind {
        case .app(let url):
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        case .file(let url):
            if revealInFinder {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                NSWorkspace.shared.open(url)
            }
        case .answer(let text):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            HapticFeedback.copy()
        }
        return true
    }

    private static func installedApps() -> [URL] {
        let fm = FileManager.default
        let roots = ["/Applications", "/Applications/Utilities", "/System/Applications",
                     "/System/Applications/Utilities", NSHomeDirectory() + "/Applications"]
        var seen = Set<String>()
        var apps: [URL] = []
        for root in roots {
            guard let names = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for name in names where name.hasSuffix(".app") && seen.insert(name).inserted {
                apps.append(URL(fileURLWithPath: root).appendingPathComponent(name))
            }
        }
        return apps
    }
}

// MARK: - Window

final class QuickSearchController: NSObject, NSWindowDelegate {
    static let shared = QuickSearchController()

    private var hotKey: GlobalHotKey?
    private var panel: QuickSearchPanel?
    private let model = QuickSearchModel()

    func setEnabled(_ enabled: Bool) {
        if enabled {
            guard hotKey == nil else { return }
            hotKey = GlobalHotKey(
                keyCode: kVK_Space,
                modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue
            ) { [weak self] in
                DispatchQueue.main.async { self?.toggle() }
            }
        } else {
            hotKey = nil
            close()
        }
    }

    func toggle() {
        if let panel, panel.isVisible { close() } else { show() }
    }

    func show() {
        model.prepare()
        if panel == nil {
            let panel = QuickSearchPanel(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.delegate = self
            panel.contentView = NSHostingView(rootView: QuickSearchView(model: model) { [weak self] in self?.close() })
            self.panel = panel
        }
        guard let panel else { return }
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.maxY - frame.height * 0.22 - panel.frame.height))
        }
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
    }

    // Clicking anywhere else closes it, like Spotlight.
    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}

private final class QuickSearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

struct QuickSearchView: View {
    @Bindable var model: QuickSearchModel
    let onClose: () -> Void
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search apps and files, or type math like 12*4 or 5 km to mi", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22))
                    .focused($fieldFocused)
                    .onSubmit {
                        if model.activate(revealInFinder: NSEvent.modifierFlags.contains(.command)) { onClose() }
                    }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            if !model.results.isEmpty {
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                                resultRow(result, isSelected: index == model.selection)
                                    .id(index)
                                    .onTapGesture {
                                        model.selection = index
                                        if model.activate(result) { onClose() }
                                    }
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 340)
                    .onChange(of: model.selection) { _, index in proxy.scrollTo(index) }
                }
            }
        }
        .frame(width: 640)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.12)))
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear { fieldFocused = true }
        .onKeyPress(.downArrow) { model.moveSelection(1); return .handled }
        .onKeyPress(.upArrow) { model.moveSelection(-1); return .handled }
        .onKeyPress(.escape) { onClose(); return .handled }
    }

    private func resultRow(_ result: QuickSearchResult, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Group {
                if let icon = result.icon {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: "equal.circle.fill").resizable().foregroundStyle(.orange)
                }
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(result.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Text(result.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.accentColor.opacity(0.35) : .clear))
        .contentShape(Rectangle())
    }
}
