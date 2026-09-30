//
//  QuickLookups.swift
//  PepBox
//
//  Quick Search answers that look something up on this Mac: dictionary
//  definitions, clipboard history, recent downloads, IP addresses, what's
//  listening on a port, keep-awake, emoji, and clipboard word counts.
//

import AppKit
import CoreServices
import SwiftUI

enum QuickLookups {
    /// Immediate results; `late` receives any that arrive later (the public IP).
    static func results(for text: String, late: @escaping ([QuickSearchResult]) -> Void) -> [QuickSearchResult] {
        let lower = text.lowercased()
        var results: [QuickSearchResult] = []

        // Dictionary: "define serendipity"
        if lower.hasPrefix("define ") {
            let word = String(text.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            if !word.isEmpty {
                let range = CFRange(location: 0, length: (word as NSString).length)
                if let definition = DCSCopyTextDefinition(nil, word as CFString, range)?.takeRetainedValue() as String? {
                    let short = definition.count > 140 ? String(definition.prefix(139)) + "…" : definition
                    results.append(QuickSearchResult(id: "define", title: short, subtitle: "Definition of \(word) · Enter to copy",
                                                     kind: .answer(definition), customSymbol: "book.fill"))
                }
                if let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   let url = URL(string: "dict://\(encoded)") {
                    results.append(QuickSearchResult(id: "define-open", title: "Open “\(word)” in Dictionary", subtitle: "Dictionary", kind: .openURL(url)))
                }
            }
        }

        // Clipboard history: "cb invoice"
        if lower.hasPrefix("cb ") || lower == "cb" {
            let needle = String(lower.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            let matches = ClipboardManager.shared.history.filter { item in
                guard item.type == .text || item.type == .url, !item.isConcealed, let content = item.content else { return false }
                return needle.isEmpty || content.lowercased().contains(needle)
            }
            results += matches.prefix(6).map { item in
                let content = item.content ?? ""
                let oneLine = content.replacingOccurrences(of: "\n", with: " ")
                return QuickSearchResult(id: "cb-\(item.id)", title: oneLine.count > 80 ? String(oneLine.prefix(79)) + "…" : oneLine,
                                         subtitle: "Clipboard history · Enter to copy", kind: .answer(content), customSymbol: "doc.on.clipboard")
            }
        }

        // Recent downloads: "downloads" / "dl"
        if ["downloads", "download", "dl", "recent downloads"].contains(lower) {
            let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.addedToDirectoryDateKey],
                                                                      options: [.skipsHiddenFiles])) ?? []
            let recent = files
                .map { ($0, (try? $0.resourceValues(forKeys: [.addedToDirectoryDateKey]).addedToDirectoryDate) ?? .distantPast) }
                .sorted { $0.1 > $1.1 }
                .prefix(6)
            let formatter = RelativeDateTimeFormatter()
            results += recent.map { url, added in
                QuickSearchResult(id: url.path, title: url.lastPathComponent, subtitle: "Downloaded \(formatter.localizedString(for: added, relativeTo: Date()))",
                                  kind: .file(url))
            }
        }

        // IP addresses: "ip"
        if ["ip", "my ip", "ip address"].contains(lower) {
            if let local = localIPAddress() {
                results.append(QuickSearchResult(id: "ip-local", title: local, subtitle: "Local IP · Enter to copy",
                                                 kind: .answer(local), customSymbol: "wifi"))
            }
            if let url = URL(string: "https://api.ipify.org") {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    guard let data, let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !ip.isEmpty, ip.count < 64 else { return }
                    DispatchQueue.main.async {
                        late([QuickSearchResult(id: "ip-public", title: ip, subtitle: "Public IP (ipify.org) · Enter to copy",
                                                kind: .answer(ip), customSymbol: "globe")])
                    }
                }.resume()
            }
        }

        // Ports: "port 3000" → what's listening, Enter stops it
        if let port = QuickTools.portQuery(text) {
            let listeners = QuickTools.parseLsof(run("/usr/sbin/lsof", ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-F", "pc"]))
            if listeners.isEmpty {
                results.append(QuickSearchResult(id: "port-free", title: "Nothing is listening on port \(port)", subtitle: "Port",
                                                 kind: .answer(String(port)), customSymbol: "network"))
            }
            results += listeners.map { pid, command in
                QuickSearchResult(id: "port-\(pid)", title: "Stop \(command) (pid \(pid)) on port \(port)",
                                  subtitle: "Listening on :\(port) · Enter to stop it", kind: .stopProcess(pid))
            }
        }

        // Keep awake: "awake 1h", "awake off"
        if let request = QuickTools.awakeRequest(text) {
            switch request {
            case .off:
                results.append(QuickSearchResult(id: "awake-off", title: "Allow Sleep", subtitle: "Turn keep-awake off", kind: .awake(nil)))
            case .indefinite:
                results.append(QuickSearchResult(id: "awake-on", title: "Stay Awake", subtitle: "Until you turn it off", kind: .awake(.indefinite)))
            case .minutes(let minutes):
                let duration: CaffeineDuration = minutes % 60 == 0 ? .hours(minutes / 60) : .minutes(minutes)
                results.append(QuickSearchResult(id: "awake-timed", title: "Stay Awake for \(duration.displayName)",
                                                 subtitle: "Keeps the Mac and display on", kind: .awake(duration)))
            }
        }

        // Snippets: ";" lists them, ";si" narrows; Enter copies the expansion
        if lower.hasPrefix(";") {
            let matches = SnippetController.snippets.filter { $0.trigger.lowercased().hasPrefix(lower) || lower == ";" }
            results += matches.prefix(8).map { snippet in
                let expanded = SnippetEngine.expand(snippet.text, clipboard: NSPasteboard.general.string(forType: .string))
                let preview = expanded.replacingOccurrences(of: "\n", with: " ")
                return QuickSearchResult(id: "snippet-\(snippet.id)", title: "\(snippet.trigger)  \(preview.prefix(70))",
                                         subtitle: "Snippet · Enter to copy", kind: .answer(expanded), customSymbol: "text.insert")
            }
        }

        // Emoji: ":fire", ":heart eyes"
        if lower.hasPrefix(":"), lower.count >= 3 {
            let needle = String(lower.dropFirst())
            let matches = EmojiCatalog.all.filter { $0.name.contains(needle) }
                .sorted { ($0.name.hasPrefix(needle) ? 0 : 1, $0.name.count) < ($1.name.hasPrefix(needle) ? 0 : 1, $1.name.count) }
            results += matches.prefix(6).map { entry in
                QuickSearchResult(id: "emoji-\(entry.emoji)", title: "\(entry.emoji)  \(entry.name)", subtitle: "Emoji · Enter to copy",
                                  kind: .answer(entry.emoji), customSymbol: "face.smiling")
            }
        }

        // Clipboard stats: "count"
        if ["count", "word count", "wc"].contains(lower), let clip = NSPasteboard.general.string(forType: .string) {
            let words = clip.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
            let lines = clip.split(separator: "\n", omittingEmptySubsequences: false).count
            let summary = "\(words) words · \(clip.count) characters · \(lines) line\(lines == 1 ? "" : "s")"
            results.append(QuickSearchResult(id: "count", title: summary, subtitle: "Clipboard text · Enter to copy",
                                             kind: .answer(summary), customSymbol: "textformat.123"))
        }

        results += assistantCommands(text)
        return results
    }

    /// "note …", "todo …", "remind … in …", "join", "agenda", "weather", media keys, "force quit"/"hide".
    private static func assistantCommands(_ text: String) -> [QuickSearchResult] {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        var results: [QuickSearchResult] = []

        if let note = QuickTools.argument(text, after: ["note", "jot"]) {
            results.append(QuickSearchResult(id: "note-add", title: "New note: \(note)", subtitle: "Notes · Enter to save",
                                             kind: .action {
                QuickNotesStore.shared.addNote(text: note)
                FlashActivity.shared.show(LiveActivity(id: "note-\(UUID())", icon: "note.text", tint: .yellow, text: "Note saved", progress: nil))
            }, customSymbol: "note.text.badge.plus"))
        }
        if let task = QuickTools.argument(text, after: ["todo", "task"]) {
            results.append(QuickSearchResult(id: "todo-add", title: "Add task: \(task)", subtitle: "To-do · Enter to add",
                                             kind: .action {
                ToDoManager.shared.addItem(title: task, priority: .normal)
                FlashActivity.shared.show(LiveActivity(id: "todo-\(UUID())", icon: "checklist", tint: .blue, text: "Task added", progress: nil))
            }, customSymbol: "checklist"))
        }
        if let event = QuickTools.eventRequest(text) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = event.isAllDay ? .none : .short
            results.append(QuickSearchResult(id: "event-add", title: "Add “\(event.title)”",
                                             subtitle: "\(formatter.string(from: event.start))\(event.isAllDay ? " · all day" : " · 1 hour") · Enter to add to Calendar",
                                             kind: .action {
                UpNextCalendar.shared.addEvent(title: event.title, start: event.start, allDay: event.isAllDay) { added in
                    FlashActivity.shared.show(LiveActivity(id: "event-\(UUID())", icon: added ? "calendar.badge.plus" : "calendar.badge.exclamationmark",
                                                           tint: added ? .blue : .orange,
                                                           text: added ? "Event added" : "Couldn't add event", progress: nil))
                }
            }, customSymbol: "calendar.badge.plus"))
        }
        if let reminder = QuickTools.reminder(text) {
            results.append(QuickSearchResult(id: "remind", title: "Remind “\(reminder.label ?? "")” in \(QuickTimerParser.format(reminder.seconds))",
                                             subtitle: "Chimes and shows beside the notch", kind: .startTimer(reminder), customSymbol: "bell.fill"))
        }

        let calendar = UpNextCalendar.shared
        if ["join", "join meeting", "join next"].contains(lower) {
            calendar.reload()
            if let meeting = calendar.events.first(where: { $0.joinURL != nil && $0.end > Date() }), let url = meeting.joinURL {
                results.append(QuickSearchResult(id: "join", title: "Join \(meeting.title)",
                                                 subtitle: "\(UpNextCalendar.relative(meeting.start, from: Date())) · \(url.host ?? "")",
                                                 kind: .openURL(url), customSymbol: "video.fill"))
            } else {
                results.append(QuickSearchResult(id: "join-none", title: calendar.authorized ? "No meeting links coming up" : "Allow Calendar in Up Next to use join",
                                                 subtitle: "Up Next", kind: .action {}, customSymbol: "video.slash"))
            }
        }
        if ["agenda", "today", "calendar", "schedule"].contains(lower) {
            calendar.reload()
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            results += calendar.events.prefix(6).map { event in
                QuickSearchResult(id: "agenda-\(event.id)", title: "\(formatter.string(from: event.start))  \(event.title)",
                                  subtitle: event.joinURL == nil ? "Calendar" : "Calendar · Enter to join",
                                  kind: event.joinURL.map { .openURL($0) } ?? .answer(event.title), customSymbol: "calendar")
            }
        }
        if ["weather", "forecast", "temp", "temperature"].contains(lower) {
            let weather = UpNextWeather.shared
            weather.refresh()
            if let now = weather.current {
                let summary = "\(Int(now.temperature.rounded()))° · H \(Int(now.high.rounded()))° L \(Int(now.low.rounded()))°"
                results.append(QuickSearchResult(id: "weather", title: summary, subtitle: "\(weather.city ?? "") · Open-Meteo",
                                                 kind: .answer(summary), customSymbol: UpNextWeather.symbol(for: now.code)))
                let hourFormat = DateFormatter()
                hourFormat.dateFormat = "h a"
                results += now.hourly.map { hour in
                    let line = "\(hourFormat.string(from: hour.time))  \(Int(hour.temperature.rounded()))°"
                    return QuickSearchResult(id: "weather-\(hour.time.timeIntervalSince1970)", title: line, subtitle: "Forecast",
                                             kind: .answer(line), customSymbol: UpNextWeather.symbol(for: hour.code))
                }
            } else {
                results.append(QuickSearchResult(id: "weather-setup", title: "Set your city in the Up Next panel", subtitle: "Weather",
                                                 kind: .action {}, customSymbol: "cloud.sun"))
            }
        }

        if ["battery", "batt", "power"].contains(lower) {
            let (level, charging) = SystemStatsManager.battery()
            if let level {
                let remaining = QuickTools.pmsetRemaining(run("/usr/bin/pmset", ["-g", "batt"]))
                let summary = "\(Int((level * 100).rounded()))%\(charging ? " · charging" : "")\(remaining.map { " · \($0) left" } ?? "")"
                results.append(QuickSearchResult(id: "battery", title: summary, subtitle: "Battery", kind: .answer(summary),
                                                 customSymbol: charging ? "battery.100.bolt" : "battery.75"))
            }
        }
        if ["uptime", "up time"].contains(lower) {
            let seconds = Int(ProcessInfo.processInfo.systemUptime)
            let summary = "Up \(seconds / 86_400)d \((seconds % 86_400) / 3600)h \((seconds % 3600) / 60)m · macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
            results.append(QuickSearchResult(id: "uptime", title: summary, subtitle: "Since last restart", kind: .answer(summary), customSymbol: "clock.arrow.circlepath"))
        }

        if let url = QuickTools.typedURL(text) {
            results.append(QuickSearchResult(id: "open-url", title: "Open \(url.host ?? url.absoluteString)\(url.path.count > 1 ? url.path : "")",
                                             subtitle: url.absoluteString, kind: .openURL(url), customSymbol: "safari"))
        }
        if let (site, url) = QuickTools.webShortcut(text) {
            results.append(QuickSearchResult(id: "web-\(site)", title: "Search \(site) for “\(text.split(separator: " ", maxSplits: 1).last ?? "")”",
                                             subtitle: "Opens in your browser", kind: .openURL(url), customSymbol: "magnifyingglass.circle.fill"))
        }
        if let mail = QuickTools.mailto(text) {
            results.append(QuickSearchResult(id: "mailto", title: "Email \(mail.absoluteString.dropFirst(7))", subtitle: "New message",
                                             kind: .openURL(mail), customSymbol: "envelope.fill"))
        }
        if let path = QuickTools.typedPath(text) {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
                results.append(QuickSearchResult(id: "path-\(path)", title: (path as NSString).abbreviatingWithTildeInPath,
                                                 subtitle: isDirectory.boolValue ? "Folder · Enter to open" : "File · Enter to open",
                                                 kind: .file(URL(fileURLWithPath: path))))
            }
        }
        if let payload = QuickTools.argument(text, after: ["qr"]) {
            results.append(QuickSearchResult(id: "qr", title: "Show QR code for “\(payload.prefix(40))”", subtitle: "Scan with your phone",
                                             kind: .action { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { QRCodePanelController.shared.show(payload) } },
                                             customSymbol: "qrcode"))
        }
        switch lower {
        case "screenshot", "screen shot", "capture":
            results.append(QuickSearchResult(id: "screenshot", title: "Screenshot to Shelf", subtitle: "Select an area",
                                             kind: .action { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { RingMenuController.screenshotToShelf() } },
                                             customSymbol: "camera.viewfinder"))
        case "focus stats", "pomodoro stats", "streak":
            let today = FocusHistory.today()
            let streak = FocusHistory.streak(FocusHistory.sessionsByDay, now: Date())
            let summary = "Today \(today.sessions) sessions · \(today.minutes) min · \(streak)-day streak"
            results.append(QuickSearchResult(id: "focus-stats", title: summary, subtitle: "Pomodoro", kind: .answer(summary), customSymbol: "flame.fill"))
        case "queue", "paste queue", "stack", "collect":
            let queue = PasteQueue.shared
            results.append(QuickSearchResult(id: "paste-queue", title: queue.isActive ? "Stop Paste Queue" : "Start Paste Queue",
                                             subtitle: queue.isActive ? "\(queue.items.count) queued" : "Copy things, then ⌃⌥V pastes them in order",
                                             kind: .action { queue.toggle() }, customSymbol: "square.stack.3d.up.fill"))
        case "pin", "float", "pin clipboard":
            let pasteboard = NSPasteboard.general
            if let image = NSImage(pasteboard: pasteboard), pasteboard.string(forType: .string) == nil {
                results.append(QuickSearchResult(id: "pin-image", title: "Float Clipboard Image on Screen", subtitle: "Stays above other windows",
                                                 kind: .action { FloatingPinController.shared.pin(.image(image)) }, customSymbol: "pin.fill"))
            } else if let text = pasteboard.string(forType: .string), !text.isEmpty {
                results.append(QuickSearchResult(id: "pin-text", title: "Float Clipboard Text on Screen", subtitle: String(text.prefix(60)),
                                                 kind: .action { FloatingPinController.shared.pin(.text(text)) }, customSymbol: "pin.fill"))
            }
        case "unpin", "close pins":
            results.append(QuickSearchResult(id: "unpin", title: "Close All Floating Pins", subtitle: "Float on Screen",
                                             kind: .action { FloatingPinController.shared.closeAll() }, customSymbol: "pin.slash"))
        case "agents", "agent":
            let sessions = AgentsMonitor.shared.sessions
            if sessions.isEmpty {
                results.append(QuickSearchResult(id: "agents-none", title: NotchWidgetKind.agents.isAvailable ? "No agents running right now" : "Install Agents in Settings → Extensions",
                                                 subtitle: "Agents", kind: .action {}, customSymbol: "sparkle"))
            }
            results += sessions.map { session in
                QuickSearchResult(id: "agent-\(session.project)-\(session.agent.rawValue)",
                                  title: "\(session.project.isEmpty ? session.agent.rawValue : session.project): \(AgentsMonitor.status(session))",
                                  subtitle: "\(session.agent.rawValue) · \(session.toolCount) calls · \(session.editCount) edits",
                                  kind: .action {}, customSymbol: session.state == .waiting ? "hand.raised.fill" : "sparkle")
            }
        case "clear clipboard", "empty clipboard":
            results.append(QuickSearchResult(id: "clear-clipboard", title: "Clear Clipboard", subtitle: "History is kept",
                                             kind: .action { NSPasteboard.general.clearContents() }, customSymbol: "clipboard"))
        case "pick color", "color picker", "eyedropper":
            results.append(QuickSearchResult(id: "pick-color", title: "Pick a Color on Screen", subtitle: "Copied as hex",
                                             kind: .action { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { RingMenuController.pickColor() } },
                                             customSymbol: "eyedropper"))
        default:
            break
        }

        let music = MusicManager.shared
        switch lower {
        case "play", "pause", "play pause", "playpause":
            results.append(QuickSearchResult(id: "media-toggle", title: music.isPlaying ? "Pause" : "Play", subtitle: "Now Playing",
                                             kind: .action { music.togglePlay() }, customSymbol: music.isPlaying ? "pause.fill" : "play.fill"))
        case "next", "skip", "next song", "next track":
            results.append(QuickSearchResult(id: "media-next", title: "Next Track", subtitle: "Now Playing",
                                             kind: .action { music.nextTrack() }, customSymbol: "forward.fill"))
        case "prev", "previous", "back", "previous track":
            results.append(QuickSearchResult(id: "media-prev", title: "Previous Track", subtitle: "Now Playing",
                                             kind: .action { music.previousTrack() }, customSymbol: "backward.fill"))
        default:
            break
        }

        for (verb, forced) in [("force quit", true), ("hide", false)] {
            guard let name = QuickTools.argument(text, after: [verb])?.lowercased() else { continue }
            let apps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
                .filter { ($0.localizedName ?? "").lowercased().hasPrefix(name) }
                .prefix(4)
            results += apps.map { app in
                let appName = app.localizedName ?? "App"
                return QuickSearchResult(id: "\(verb)-\(app.processIdentifier)", title: "\(forced ? "Force Quit" : "Hide") \(appName)",
                                         subtitle: forced ? "Unsaved work in \(appName) is lost" : "Command",
                                         kind: .action {
                                             if forced { app.forceTerminate() } else { app.hide() }
                                         },
                                         customSymbol: forced ? "exclamationmark.octagon.fill" : "eye.slash")
            }
        }
        return results
    }

    private static func localIPAddress() -> String? {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return nil }
        defer { freeifaddrs(addresses) }
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            let name = String(cString: current.pointee.ifa_name)
            if name.hasPrefix("en"), let address = current.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    return String(cString: host)
                }
            }
            pointer = current.pointee.ifa_next
        }
        return nil
    }

    static func run(_ path: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
