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
        case startTimer(QuickTimerParser.Request)
        case cancelTimer(UUID)
        case command(QuickCommand)
        case openURL(URL)
        case stopProcess(pid_t)
        case awake(CaffeineDuration?)   // nil turns keep-awake off
        case action(() -> Void)          // runs, then Quick Search closes
        case fillQuery(String)           // puts text in the search field; the panel stays open
    }

    let id: String
    let title: String
    let subtitle: String
    let kind: Kind

    /// Overrides the default symbol (tools set their own).
    var customSymbol: String? = nil

    var symbol: String {
        if let customSymbol { return customSymbol }
        switch kind {
        case .startTimer: return "timer"
        case .cancelTimer: return "xmark.circle.fill"
        case .command(let command): return command.symbol
        case .openURL: return "book.fill"
        case .action: return "bolt.fill"
        case .fillQuery: return "questionmark.circle"
        case .stopProcess: return "stop.circle.fill"
        case .awake: return "cup.and.saucer.fill"
        default: return "equal.circle.fill"
        }
    }

    var icon: NSImage? {
        switch kind {
        case .app(let url), .file(let url):
            return NSWorkspace.shared.icon(forFile: url.path)
        case .answer, .startTimer, .cancelTimer, .command, .openURL, .stopProcess, .awake, .action, .fillQuery:
            return nil
        }
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
    /// Bumped on every open so the view re-focuses its field (onAppear only fires once).
    private(set) var openCount = 0

    private var apps: [URL] = []
    private var fileResults: [QuickSearchResult] = []
    private var fileQuery: NSMetadataQuery?
    private var fileQueryObserver: NSObjectProtocol?

    func prepare() {
        openCount += 1
        query = ""
        selection = 0
        apps = Self.installedApps()
        QuickCurrencyRates.refreshIfStale()
    }

    private func search() {
        selection = 0
        let text = query.trimmingCharacters(in: .whitespaces)
        var list: [QuickSearchResult] = []
        guard !text.isEmpty else {
            results = suggestions()
            stopFileQuery()
            return
        }

        if text == "?" || text.lowercased() == "help" {
            // A cheat sheet: Enter puts the example in the search field.
            let examples: [(String, String, String)] = [
                ("12*4 or (3+2)^2", "Math", "plus.forwardslash.minus"),
                ("5 km to mi · $20 to eur", "Units and currency", "arrow.left.arrow.right"),
                ("time in tokyo · 3pm est in pst", "Time zones", "globe"),
                ("days until dec 25 · today + 30 days", "Dates", "calendar"),
                ("timer 10m pizza · remind stretch in 20m", "Timers and reminders", "timer"),
                ("#ff8800 · 255 in hex · 15% of 80", "Colors, numbers, percentages", "number"),
                ("note buy milk · todo call Sam", "Notes and tasks", "note.text"),
                ("event lunch with Sam tomorrow 1pm", "Calendar events", "calendar.badge.plus"),
                ("join · agenda · weather", "Your day", "sun.max"),
                ("cb invoice · count · queue", "Clipboard", "doc.on.clipboard"),
                ("define serendipity · yt lofi · github.com", "Look things up", "book"),
                ("port 3000 · ip · battery · awake 1h", "Your Mac", "laptopcomputer"),
                ("lock · sleep · quit Slack · wifi", "Commands and settings", "power"),
                ("ocr · screenshot · pick color · qr hello", "Screen tools", "text.viewfinder"),
                (":fire · uuid · password 24 · base64 hi", "Generators", "wand.and.stars"),
                ("sha256 hi · jwt eyJ… · http 404 · chmod 755 · dns github.com", "Developer", "chevron.left.forwardslash.chevron.right"),
                ("contrast #fff #333 · 24px · roman 2026 · char 65", "Design and text", "paintbrush"),
                ("stopwatch · clocks · sunrise · week · split 120 by 4", "Time and money", "stopwatch"),
                ("volume 50 · mute · brightness 70 · upper · json", "Sound, display, clipboard", "slider.horizontal.3")
            ]
            results = examples.map { example, title, symbol in
                let first = example.components(separatedBy: " · ").first ?? example
                return QuickSearchResult(id: "help-\(title)", title: example, subtitle: title,
                                         kind: .fillQuery(first),
                                         customSymbol: symbol)
            }
            stopFileQuery()
            return
        }

        if let value = QuickCalculator.evaluate(text) {
            let answer = QuickCalculator.format(value)
            list.append(QuickSearchResult(id: "math", title: answer, subtitle: "= \(text) · Enter to copy", kind: .answer(answer)))
        }
        if let converted = QuickUnitConverter.convert(text) {
            list.append(QuickSearchResult(id: "unit", title: converted, subtitle: "\(text) · Enter to copy", kind: .answer(converted)))
        } else if let converted = QuickCurrencyConverter.convert(text, rates: QuickCurrencyRates.cached) {
            list.append(QuickSearchResult(id: "currency", title: converted, subtitle: "\(text) · daily rates · Enter to copy", kind: .answer(converted)))
        }

        if let request = QuickTimerParser.parse(text) {
            let name = request.label.map { " for \($0)" } ?? ""
            list.append(QuickSearchResult(id: "timer", title: "Start \(QuickTimerParser.format(request.seconds)) timer\(name)",
                                          subtitle: "Counts down beside the notch · Enter to start", kind: .startTimer(request)))
        }
        if ["timer", "timers"].contains(text.lowercased()) {
            let manager = QuickTimerManager.shared
            list += manager.timers.map { timer in
                QuickSearchResult(id: "cancel-\(timer.id)", title: "\(timer.title) · \(QuickTimerParser.format(manager.remaining(timer))) left",
                                  subtitle: "Enter to cancel", kind: .cancelTimer(timer.id))
            }
        }

        let toolAnswers = QuickTools.answers(for: text) + QuickTools.devTools(text)
            + (["clocks", "world clock", "world clocks"].contains(text.lowercased()) ? QuickTools.worldClocks() : [])
        list += toolAnswers.map {
            QuickSearchResult(id: $0.id, title: $0.title, subtitle: $0.subtitle, kind: .answer($0.copy), customSymbol: $0.symbol)
        }
        list += QuickLookups.results(for: text) { [weak self] late in
            // Slow answers (public IP) arrive after typing; add them if the query hasn't changed.
            guard let self, self.query.trimmingCharacters(in: .whitespaces) == text else { return }
            let insertAt = self.results.firstIndex { if case .app = $0.kind { return true } else { return false } } ?? self.results.count
            self.results.insert(contentsOf: late, at: insertAt)
        }

        let lower = text.lowercased()
        let appsByName = Dictionary(apps.map { ($0.deletingPathExtension().lastPathComponent, $0) }, uniquingKeysWith: { first, _ in first })
        let matchingApps = QuickTools.rankApps(Array(appsByName.keys), query: lower, usage: Self.appUsage)
            .prefix(6)
            .compactMap { name in appsByName[name].map { ($0, name) } }
        list += matchingApps.map { url, name in
            QuickSearchResult(id: url.path, title: name, subtitle: "Application", kind: .app(url))
        }

        // Commands come after apps, so "sl" + Enter opens Slack rather than sleeping the Mac.
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .compactMap { app in app.localizedName.map { ($0, app.processIdentifier) } }
        list += QuickCommand.matches(text, runningApps: running).map {
            QuickSearchResult(id: "command-\($0.title)", title: $0.title, subtitle: $0.subtitle, kind: .command($0))
        }

        // Web search is the fallback, so it stays last (after files arrive too).
        let web = QuickCommand.webSearch(text)
        list.append(QuickSearchResult(id: "web", title: web.title, subtitle: web.subtitle, kind: .command(web)))

        results = list
        startFileQuery(for: text)
    }

    // MARK: Usage and suggestions

    private static let usageKey = "quickSearch_appUsage"

    static var appUsage: [String: Int] {
        UserDefaults.standard.dictionary(forKey: usageKey) as? [String: Int] ?? [:]
    }

    static func noteAppOpened(_ name: String) {
        var usage = appUsage
        usage[name, default: 0] += 1
        UserDefaults.standard.set(usage, forKey: usageKey)
    }

    /// What Quick Search shows before you type: running timers / queue, then your most-opened apps.
    private func suggestions() -> [QuickSearchResult] {
        var list: [QuickSearchResult] = []
        let timers = QuickTimerManager.shared
        list += timers.timers.map { timer in
            QuickSearchResult(id: "cancel-\(timer.id)", title: "\(timer.title) · \(QuickTimerParser.format(timers.remaining(timer))) left",
                              subtitle: "Timer · Enter to cancel", kind: .cancelTimer(timer.id))
        }
        if PasteQueue.shared.isActive {
            list.append(QuickSearchResult(id: "queue-stop", title: "Stop Paste Queue (\(PasteQueue.shared.items.count) queued)",
                                          subtitle: "Paste Queue", kind: .action { PasteQueue.shared.stop() }, customSymbol: "square.stack.3d.up.fill"))
        }
        let appsByName = Dictionary(apps.map { ($0.deletingPathExtension().lastPathComponent, $0) }, uniquingKeysWith: { first, _ in first })
        let favorites = Self.appUsage.sorted { $0.value > $1.value }.prefix(6).compactMap { name, _ in appsByName[name].map { (name, $0) } }
        list += favorites.map { name, url in
            QuickSearchResult(id: url.path, title: name, subtitle: "Frequently used", kind: .app(url))
        }
        return list
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
        let nonFiles = results.filter { result in
            if case .file = result.kind { return false }
            return result.id != "web"
        }
        results = nonFiles + files + results.filter { $0.id == "web" }
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
            Self.noteAppOpened(url.deletingPathExtension().lastPathComponent)
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
        case .startTimer(let request):
            QuickTimerManager.shared.start(request)
        case .cancelTimer(let id):
            QuickTimerManager.shared.cancel(id)
        case .command(.grabText):
            // Let the search panel close before the capture crosshair appears.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { ScreenTextGrabber.start() }
        case .command(let command):
            command.run()
        case .openURL(let url):
            NSWorkspace.shared.open(url)
        case .action(let run):
            run()
        case .fillQuery(let text):
            query = text
            return false
        case .stopProcess(let pid):
            kill(pid, SIGTERM)
        case .awake(let duration):
            if let duration { CaffeineManager.shared.activate(duration: duration) } else { CaffeineManager.shared.deactivate() }
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
            let shortcut = ExtensionShortcuts.load(ExtensionShortcuts.quickSearchKey, default: ExtensionShortcuts.quickSearchDefault)
            hotKey = GlobalHotKey(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in
                DispatchQueue.main.async { self?.toggle() }
            }
        } else {
            hotKey = nil
            close()
        }
    }

    /// Re-registers the hotkey after the shortcut changed in the extension's options.
    func reloadShortcut() {
        guard hotKey != nil else { return }
        hotKey = nil
        setEnabled(true)
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
                TextField("Search apps, files and commands. Type ? for everything it can do", text: $model.query)
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
        .onChange(of: model.openCount) { _, _ in fieldFocused = true }
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
                    Image(systemName: result.symbol).resizable().foregroundStyle(.orange)
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
