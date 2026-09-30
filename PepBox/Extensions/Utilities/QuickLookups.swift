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

    private static func run(_ path: String, _ arguments: [String]) -> String {
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
