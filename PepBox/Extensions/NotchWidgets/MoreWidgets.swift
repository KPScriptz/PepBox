//
//  MoreWidgets.swift
//  PepBox
//
//  Twenty small shelf widgets: clocks, calculator, dice, colors, countdowns,
//  stopwatch, timers, habits, water, breathing, network, recent clips,
//  downloads, screenshots, links, passwords, day progress, moon, counter and
//  a month calendar. Each lives in the shared widget slot under the shelf.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

// MARK: - Shared look

private struct WidgetHeader: View {
    let title: String
    var trailing: AnyView? = nil
    var body: some View {
        HStack {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
            Spacer()
            trailing
        }
    }
}

private struct PillButton: View {
    let title: String
    var tint: Color = .white.opacity(0.12)
    var foreground: Color = .white
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(tint))
        }
        .buttonStyle(.plain)
    }
}

private func copyToClipboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    HapticFeedback.copy()
}

/// JSON-in-UserDefaults storage for small widget lists.
private enum WidgetStore {
    static func load<T: Decodable>(_ key: String, default value: T) -> T {
        guard let data = UserDefaults.standard.data(forKey: key), let decoded = try? JSONDecoder().decode(T.self, from: data) else { return value }
        return decoded
    }
    static func save<T: Encodable>(_ value: T, _ key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key)
    }
}

// MARK: - 1. World Clock

struct WorldClockWidgetView: View {
    @State private var cities: [String] = WidgetStore.load("widget_worldClock_cities", default: ["New York", "London", "Tokyo", "Los Angeles"])
    @State private var input = ""
    @State private var now = Date()
    private let tick = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: "World Clock", trailing: AnyView(
                TextField("Add city", text: $input)
                    .textFieldStyle(.plain).font(.system(size: 11)).foregroundStyle(.white)
                    .frame(width: 110).padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.1)))
                    .onSubmit(add)))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(cities, id: \.self) { city in
                    let zone = QuickTools.zone(named: city)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(time(in: zone)).font(.system(size: 18, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                        Text(city).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))
                    .contextMenu { Button("Remove") { cities.removeAll { $0 == city }; WidgetStore.save(cities, "widget_worldClock_cities") } }
                }
            }
        }
        .onReceive(tick) { now = $0 }
    }

    private func time(in zone: TimeZone?) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone ?? .current
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: now)
    }

    private func add() {
        let name = input.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, QuickTools.zone(named: name) != nil, !cities.contains(name) else { NSSound.beep(); return }
        cities = Array((cities + [name.capitalized]).suffix(8))
        WidgetStore.save(cities, "widget_worldClock_cities")
        input = ""
    }
}

// MARK: - 2. Calculator

struct CalculatorWidgetView: View {
    @State private var display = "0"
    private let keys = [["C", "⌫", "%", "÷"], ["7", "8", "9", "×"], ["4", "5", "6", "−"], ["1", "2", "3", "+"], ["0", ".", "(", "="]]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(display)
                    .font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Button("Copy") { copyToClipboard(display) }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 170)
            Grid(horizontalSpacing: 5, verticalSpacing: 5) {
                ForEach(keys, id: \.self) { row in
                    GridRow {
                        ForEach(row, id: \.self) { key in
                            Button { display = WidgetMath.calculatorKey(key == "(" && display.contains("(") ? ")" : key, display: display) } label: {
                                Text(key == "(" ? "( )" : key)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 42, height: 22)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(key == "=" ? Color.orange : ["÷", "×", "−", "+"].contains(key) ? .white.opacity(0.2) : .white.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 3. Dice & Coin

struct DiceWidgetView: View {
    @State private var result = "🎲"
    @State private var detail = "Roll or flip"

    var body: some View {
        HStack(spacing: 18) {
            VStack(spacing: 4) {
                Text(result).font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(.white).contentTransition(.numericText())
                Text(detail).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 140)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    PillButton(title: "d6") { roll(1, 6) }
                    PillButton(title: "2d6") { roll(2, 6) }
                    PillButton(title: "d20") { roll(1, 20) }
                    PillButton(title: "d100") { roll(1, 100) }
                }
                HStack(spacing: 8) {
                    PillButton(title: "Flip a coin", tint: .orange.opacity(0.8)) {
                        withAnimation { result = Bool.random() ? "Heads" : "Tails" }
                        detail = "Coin flip"
                    }
                    PillButton(title: "Yes / No") { withAnimation { result = Bool.random() ? "Yes" : "No" }; detail = "Decision" }
                }
            }
        }
    }

    private func roll(_ count: Int, _ sides: Int) {
        let rolls = (0..<count).map { _ in Int.random(in: 1...sides) }
        withAnimation { result = String(rolls.reduce(0, +)) }
        detail = count > 1 ? rolls.map(String.init).joined(separator: " + ") : "d\(sides)"
    }
}

// MARK: - 4. Color Picker

struct ColorPickerWidgetView: View {
    @State private var colors: [String] = WidgetStore.load("widget_colorPicker_history", default: [])

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PillButton(title: "Pick a color on screen", tint: .pink.opacity(0.8)) {
                    NSColorSampler().show { color in
                        guard let c = color?.usingColorSpace(.sRGB) else { return }
                        let hex = String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
                        copyToClipboard(hex)
                        colors = Array(([hex] + colors.filter { $0 != hex }).prefix(10))
                        WidgetStore.save(colors, "widget_colorPicker_history")
                    }
                }
                Spacer()
                Text("Click a swatch to copy").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            }
            if colors.isEmpty {
                Text("Colors you pick appear here.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            } else {
                HStack(spacing: 8) {
                    ForEach(colors, id: \.self) { hex in
                        let rgb = QuickTools.hexColor(hex) ?? (0, 0, 0)
                        Button { copyToClipboard(hex) } label: {
                            VStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 8).fill(Color(red: rgb.0, green: rgb.1, blue: rgb.2)).frame(width: 34, height: 34)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.2)))
                                Text(hex).font(.system(size: 8, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - 5. Countdown

struct CountdownWidgetView: View {
    struct Item: Codable, Hashable { var title: String; var date: Date }
    @State private var items: [Item] = WidgetStore.load("widget_countdown_items", default: [])
    @State private var title = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                TextField("Vacation, launch, birthday…", text: $title)
                    .textFieldStyle(.plain).font(.system(size: 12)).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(.white.opacity(0.1)))
                DatePicker("", selection: $date, displayedComponents: .date).labelsHidden().frame(width: 110)
                PillButton(title: "Add", tint: .purple.opacity(0.8)) {
                    let name = title.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    items = Array((items + [Item(title: name, date: date)]).sorted { $0.date < $1.date }.prefix(6))
                    WidgetStore.save(items, "widget_countdown_items")
                    title = ""
                }
            }
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    let days = WidgetMath.daysUntil(item.date, from: Date())
                    VStack(spacing: 1) {
                        Text(days == 0 ? "Today" : "\(abs(days))").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(days < 0 ? .white.opacity(0.4) : .white)
                        Text(days == 0 ? "" : days > 0 ? "days to go" : "days ago").font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
                        Text(item.title).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                    }
                    .frame(width: 84).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))
                    .contextMenu { Button("Remove") { items.removeAll { $0 == item }; WidgetStore.save(items, "widget_countdown_items") } }
                }
            }
        }
    }
}

// MARK: - 6. Stopwatch

struct StopwatchWidgetView: View {
    var manager: StopwatchManager
    @State private var laps: [TimeInterval] = []

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(StopwatchManager.format(manager.elapsed)).font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                HStack(spacing: 8) {
                    PillButton(title: manager.isRunning ? "Stop" : "Start", tint: manager.isRunning ? .red.opacity(0.8) : .green.opacity(0.8)) {
                        if !manager.isRunning { laps = [] }
                        manager.toggle()
                    }
                    if manager.isRunning { PillButton(title: "Lap") { laps.insert(manager.elapsed, at: 0) } }
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(laps.prefix(5).enumerated()), id: \.offset) { index, lap in
                    Text("Lap \(laps.count - index)   \(StopwatchManager.format(lap))").font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - 7. Timers

struct TimersWidgetView: View {
    var manager: QuickTimerManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach([1, 3, 5, 10, 15, 25, 45], id: \.self) { minutes in
                    PillButton(title: "\(minutes)m") { manager.start(.init(seconds: TimeInterval(minutes * 60), label: nil)) }
                }
            }
            if manager.timers.isEmpty {
                Text("Tap a length to start a timer. It counts down beside the notch.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            } else {
                HStack(spacing: 8) {
                    ForEach(manager.timers) { timer in
                        HStack(spacing: 6) {
                            Text(QuickTimerParser.format(manager.remaining(timer))).font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                            Button { manager.cancel(timer.id) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.5)) }.buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6).background(Capsule().fill(.orange.opacity(0.25)))
                    }
                }
            }
        }
    }
}

// MARK: - 8. Habits

struct HabitsWidgetView: View {
    struct Habit: Codable, Hashable { var name: String; var days: Set<String> }
    @State private var habits: [Habit] = WidgetStore.load("widget_habits", default: [Habit(name: "Exercise", days: []), Habit(name: "Read", days: []), Habit(name: "No sugar", days: [])])
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: "Today", trailing: AnyView(
                TextField("Add habit", text: $newName).textFieldStyle(.plain).font(.system(size: 11)).foregroundStyle(.white)
                    .frame(width: 100).padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(.white.opacity(0.1)))
                    .onSubmit {
                        let name = newName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty, habits.count < 5 else { return }
                        habits.append(Habit(name: name, days: [])); WidgetStore.save(habits, "widget_habits"); newName = ""
                    }))
            HStack(spacing: 8) {
                ForEach(Array(habits.enumerated()), id: \.offset) { index, habit in
                    let today = WidgetMath.dayKey(Date())
                    let done = habit.days.contains(today)
                    Button {
                        if done { habits[index].days.remove(today) } else { habits[index].days.insert(today) }
                        // Keep a year of history.
                        let cutoff = WidgetMath.dayKey(Date().addingTimeInterval(-366 * 86_400))
                        habits[index].days = habits[index].days.filter { $0 >= cutoff }
                        WidgetStore.save(habits, "widget_habits")
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(done ? .green : .white.opacity(0.4))
                            Text(habit.name).font(.system(size: 11, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                            Text("🔥 \(WidgetMath.streak(doneDays: habit.days, now: Date()))").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(width: 80).padding(.vertical, 6).background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .contextMenu { Button("Remove") { habits.remove(at: index); WidgetStore.save(habits, "widget_habits") } }
                }
            }
        }
    }
}

// MARK: - 9. Water

struct WaterWidgetView: View {
    @AppStorage("widget_water_goal") private var goal = 8
    @State private var log: [String: Int] = WidgetStore.load("widget_water_log", default: [:])

    private var today: Int { log[WidgetMath.dayKey(Date())] ?? 0 }

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 7)
                Circle().trim(from: 0, to: min(1, Double(today) / Double(max(goal, 1))))
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: today)
                VStack(spacing: 0) {
                    Text("\(today)").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("of \(goal)").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    PillButton(title: "+ Glass", tint: .cyan.opacity(0.7)) { change(1) }
                    PillButton(title: "−") { change(-1) }
                }
                Stepper("Daily goal: \(goal) glasses", value: $goal, in: 1...20).font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                Text(today >= goal ? "Goal reached 💧" : "\(goal - today) to go today").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func change(_ delta: Int) {
        let key = WidgetMath.dayKey(Date())
        log[key] = max(0, (log[key] ?? 0) + delta)
        let cutoff = WidgetMath.dayKey(Date().addingTimeInterval(-90 * 86_400))
        log = log.filter { $0.key >= cutoff }
        WidgetStore.save(log, "widget_water_log")
    }
}

// MARK: - 10. Breathe

struct BreatheWidgetView: View {
    @State private var running = false
    @State private var phase = 0
    @State private var expanded = false
    private let phases = ["Breathe in", "Hold", "Breathe out", "Hold"]
    private let tick = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 22) {
            Circle()
                .fill(RadialGradient(colors: [.teal, .teal.opacity(0.2)], center: .center, startRadius: 2, endRadius: 50))
                .frame(width: 90, height: 90)
                .scaleEffect(expanded ? 1 : 0.45)
                .animation(.easeInOut(duration: 4), value: expanded)
            VStack(alignment: .leading, spacing: 8) {
                Text(running ? phases[phase] : "Box breathing").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                Text("4 seconds in, hold, out, hold. A minute or two calms things down.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                PillButton(title: running ? "Stop" : "Start", tint: .teal.opacity(0.8)) {
                    running.toggle(); phase = 0; expanded = running
                }
            }
        }
        .onReceive(tick) { _ in
            guard running else { return }
            phase = (phase + 1) % 4
            if phase == 0 { expanded = true } else if phase == 2 { expanded = false }
        }
    }
}

// MARK: - 11. Network

struct NetworkWidgetView: View {
    @State private var publicIP = "…"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row("Local IP", NetworkInfo.localIP() ?? "Not connected", "wifi")
            row("Public IP", publicIP, "globe")
            row("Computer", Host.current().localizedName ?? "Mac", "laptopcomputer")
        }
        .onAppear {
            guard let url = URL(string: "https://api.ipify.org") else { return }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                let ip = data.flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unavailable"
                DispatchQueue.main.async { publicIP = ip.count < 64 ? ip : "Unavailable" }
            }.resume()
        }
    }

    private func row(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.blue).frame(width: 18)
            Text(label).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).frame(width: 80, alignment: .leading)
            Text(value).font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(.white).textSelection(.enabled)
            Spacer()
            Button { copyToClipboard(value) } label: { Image(systemName: "doc.on.doc").foregroundStyle(.white.opacity(0.5)) }.buttonStyle(.plain)
        }
    }
}

enum NetworkInfo {
    static func localIP() -> String? {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return nil }
        defer { freeifaddrs(addresses) }
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            if String(cString: current.pointee.ifa_name).hasPrefix("en"), let address = current.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 { return String(cString: host) }
            }
            pointer = current.pointee.ifa_next
        }
        return nil
    }
}

// MARK: - 12. Recent Clips

struct RecentClipsWidgetView: View {
    @ObservedObject var manager = ClipboardManager.shared

    var body: some View {
        let clips = manager.history.filter { ($0.type == .text || $0.type == .url) && !$0.isConcealed }.prefix(6)
        VStack(alignment: .leading, spacing: 4) {
            WidgetHeader(title: "Click to copy")
            if clips.isEmpty {
                Text("Copy some text and it shows up here.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                ForEach(Array(clips), id: \.id) { clip in
                    Button { copyToClipboard(clip.content ?? "") } label: {
                        Text((clip.content ?? "").replacingOccurrences(of: "\n", with: " "))
                            .font(.system(size: 11)).foregroundStyle(.white).lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - 13 & 14. Recent files (Downloads, Screenshots)

private struct RecentFilesView: View {
    let title: String
    let folder: URL
    var onlyScreenshots = false
    @State private var files: [URL] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(title: title, trailing: AnyView(
                Button("Show in Finder") { NSWorkspace.shared.open(folder) }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))))
            if files.isEmpty {
                Text("Nothing here yet.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            }
            HStack(spacing: 8) {
                ForEach(files, id: \.self) { url in
                    VStack(spacing: 3) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 40, height: 40)
                        Text(url.lastPathComponent).font(.system(size: 9)).foregroundStyle(.white.opacity(0.8)).lineLimit(1).frame(width: 64)
                    }
                    .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
                    .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
                    .help("Double-click to open, drag to use")
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.addedToDirectoryDateKey, .creationDateKey], options: [.skipsHiddenFiles])) ?? []
        files = urls
            .filter { url in
                guard onlyScreenshots else { return true }
                let name = url.lastPathComponent.lowercased()
                return name.hasPrefix("screenshot") || name.hasPrefix("screen shot") || name.hasPrefix("screen recording")
            }
            .map { ($0, (try? $0.resourceValues(forKeys: [.addedToDirectoryDateKey]).addedToDirectoryDate) ?? .distantPast) }
            .sorted { $0.1 > $1.1 }
            .prefix(6)
            .map(\.0)
    }
}

struct DownloadsWidgetView: View {
    var body: some View {
        RecentFilesView(title: "Recent downloads", folder: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0])
    }
}

struct ScreenshotsWidgetView: View {
    /// Where macOS saves screenshots (the Desktop unless changed in the Screenshot app).
    static var folder: URL {
        let custom = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
        if let custom, !custom.isEmpty { return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath) }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }
    var body: some View {
        RecentFilesView(title: "Recent screenshots", folder: Self.folder, onlyScreenshots: true)
    }
}

// MARK: - 15. Quick Links

struct QuickLinksWidgetView: View {
    @State private var links: [String] = WidgetStore.load("widget_quickLinks", default: ["https://github.com", "https://calendar.google.com", "https://mail.google.com"])
    @State private var input = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: "Links", trailing: AnyView(
                TextField("Add a link", text: $input).textFieldStyle(.plain).font(.system(size: 11)).foregroundStyle(.white)
                    .frame(width: 150).padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(.white.opacity(0.1)))
                    .onSubmit {
                        guard let url = QuickTools.typedURL(input) else { NSSound.beep(); return }
                        links = Array((links + [url.absoluteString]).prefix(9)); WidgetStore.save(links, "widget_quickLinks"); input = ""
                    }))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(links, id: \.self) { link in
                    Button { if let url = URL(string: link) { NSWorkspace.shared.open(url) } } label: {
                        Text(URL(string: link)?.host?.replacingOccurrences(of: "www.", with: "") ?? link)
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 7).fill(.indigo.opacity(0.3)))
                    }
                    .buttonStyle(.plain)
                    .contextMenu { Button("Remove") { links.removeAll { $0 == link }; WidgetStore.save(links, "widget_quickLinks") } }
                }
            }
        }
    }
}

// MARK: - 16. Password

struct PasswordWidgetView: View {
    @State private var length = 20.0
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(password).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.5).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.07)))
            HStack(spacing: 10) {
                Text("\(Int(length)) characters").font(.system(size: 11)).foregroundStyle(.white.opacity(0.7)).frame(width: 90, alignment: .leading)
                Slider(value: $length, in: 8...64, step: 1).onChange(of: length) { _, _ in generate() }
                PillButton(title: "New") { generate() }
                PillButton(title: "Copy", tint: .yellow.opacity(0.8), foreground: .black) { copyToClipboard(password) }
            }
        }
        .onAppear(perform: generate)
    }

    private func generate() {
        password = QuickTools.generators("password \(Int(length))", random: { UInt64.random(in: .min ... .max) }).first?.copy ?? ""
    }
}

// MARK: - 17. Day Progress

struct DayProgressWidgetView: View {
    @State private var now = Date()
    private let tick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let p = WidgetMath.progress(now: now)
        VStack(alignment: .leading, spacing: 7) {
            bar("Day", p.day, .orange)
            bar("Week", p.week, .pink)
            bar("Month", p.month, .purple)
            bar("Year", p.year, .blue)
        }
        .onReceive(tick) { now = $0 }
    }

    private func bar(_ label: String, _ value: Double, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.7)).frame(width: 44, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule().fill(tint).frame(width: geo.size.width * value)
                }
            }
            .frame(height: 8)
            Text("\(Int((value * 100).rounded(.down)))%").font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.white).frame(width: 38, alignment: .trailing)
        }
    }
}

// MARK: - 18. Moon

struct MoonWidgetView: View {
    var body: some View {
        let moon = WidgetMath.moon(on: Date())
        HStack(spacing: 18) {
            Image(systemName: moon.symbol).font(.system(size: 54)).foregroundStyle(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: 4) {
                Text(moon.name).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                Text("\(Int((moon.illumination * 100).rounded()))% lit · day \(Int(moon.age.rounded())) of 29.5").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                Text(moon.name == "Full Moon" ? "Full moon tonight" : "Full moon in \(moon.daysToFull) day\(moon.daysToFull == 1 ? "" : "s")").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - 19. Counter

struct CounterWidgetView: View {
    @AppStorage("widget_counter_value") private var value = 0
    @AppStorage("widget_counter_label") private var label = "Count"

    var body: some View {
        HStack(spacing: 20) {
            Button { value -= 1 } label: { Image(systemName: "minus").font(.system(size: 20, weight: .bold)).frame(width: 50, height: 50).background(Circle().fill(.white.opacity(0.1))) }
                .buttonStyle(.plain).foregroundStyle(.white)
            VStack(spacing: 2) {
                Text("\(value)").font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(.white).contentTransition(.numericText())
                TextField("Label", text: $label).textFieldStyle(.plain).multilineTextAlignment(.center).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6)).frame(width: 120)
            }
            Button { value += 1 } label: { Image(systemName: "plus").font(.system(size: 20, weight: .bold)).frame(width: 50, height: 50).background(Circle().fill(.pink.opacity(0.7))) }
                .buttonStyle(.plain).foregroundStyle(.white)
            PillButton(title: "Reset") { value = 0 }
        }
        .animation(.snappy, value: value)
    }
}

// MARK: - 20. Month

struct MonthWidgetView: View {
    @State private var offset = 0

    var body: some View {
        let calendar = Calendar.current
        let shown = calendar.date(byAdding: .month, value: offset, to: Date()) ?? Date()
        let parts = calendar.dateComponents([.year, .month], from: shown)
        let today = calendar.dateComponents([.year, .month, .day], from: Date())
        let weeks = WidgetMath.monthGrid(year: parts.year ?? 2026, month: parts.month ?? 1)
        let symbols = (0..<7).map { calendar.veryShortWeekdaySymbols[(calendar.firstWeekday - 1 + $0) % 7] }
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(shown.formatted(.dateTime.month(.wide).year())).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                HStack(spacing: 6) {
                    PillButton(title: "‹") { offset -= 1 }
                    PillButton(title: "Today") { offset = 0 }
                    PillButton(title: "›") { offset += 1 }
                }
            }
            Grid(horizontalSpacing: 4, verticalSpacing: 2) {
                GridRow { ForEach(symbols.indices, id: \.self) { Text(symbols[$0]).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.5)).frame(width: 22) } }
                ForEach(weeks.indices, id: \.self) { w in
                    GridRow {
                        ForEach(0..<7, id: \.self) { d in
                            let day = weeks[w][d]
                            let isToday = day != nil && day == today.day && parts.month == today.month && parts.year == today.year
                            Text(day.map(String.init) ?? "")
                                .font(.system(size: 10, weight: isToday ? .bold : .regular)).monospacedDigit()
                                .foregroundStyle(isToday ? .black : .white.opacity(0.85))
                                .frame(width: 22, height: 17)
                                .background(Circle().fill(isToday ? Color.white : .clear))
                        }
                    }
                }
            }
        }
    }
}
