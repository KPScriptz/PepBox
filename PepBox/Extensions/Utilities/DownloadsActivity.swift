//
//  DownloadsActivity.swift
//  PepBox
//
//  Browser downloads as a live activity beside the notch, and finished files
//  dropped onto the shelf. Watches ~/Downloads for Safari (.download bundles,
//  with real progress), Chrome/Edge/Brave/Arc (.crdownload) and Firefox (.part).
//

import SwiftUI
import AppKit

@Observable
final class DownloadsWatcher {
    static let shared = DownloadsWatcher()

    static let addToShelfKey = "downloads_addToShelf"

    struct Download: Equatable {
        let name: String
        let bytes: Int64
        /// 0...1 when the browser tells us the total (Safari), else nil.
        let progress: Double?
    }

    private(set) var active: Download?

    private var source: DispatchSourceFileSystemObject?
    private var pollTimer: Timer?
    /// Final paths of downloads in progress, so we know what finished.
    private var pending: Set<String> = []
    private let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]

    func setEnabled(_ enabled: Bool) {
        source?.cancel()
        source = nil
        pollTimer?.invalidate()
        pollTimer = nil
        active = nil
        pending = []
        guard enabled else { return }

        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in self?.scan() }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
        scan()
    }

    /// Rescans on folder changes, and every second while something is downloading.
    private func scan() {
        let entries = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])) ?? []
        var downloads: [(Download, final: String, modified: Date)] = []

        for url in entries {
            let ext = url.pathExtension.lowercased()
            guard ["download", "crdownload", "part"].contains(ext) else { continue }
            let finalName = Self.finalName(for: url)
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if ext == "download" {
                let info = NSDictionary(contentsOf: url.appendingPathComponent("Info.plist"))
                let soFar = (info?["DownloadEntryProgressBytesSoFar"] as? NSNumber)?.int64Value ?? Self.size(ofBundle: url)
                let total = (info?["DownloadEntryProgressTotalToLoad"] as? NSNumber)?.int64Value ?? 0
                let progress = total > 0 ? min(1, Double(soFar) / Double(total)) : nil
                downloads.append((Download(name: finalName, bytes: soFar, progress: progress), finalName, modified))
            } else {
                let size = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                downloads.append((Download(name: finalName, bytes: size, progress: nil), finalName, modified))
            }
        }

        // Anything we were tracking that's no longer partial has finished (or was cancelled).
        let current = Set(downloads.map(\.final))
        let finished = pending.subtracting(current)
        pending = current
        for name in finished {
            let url = folder.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }  // cancelled
            if UserDefaults.standard.object(forKey: Self.addToShelfKey) as? Bool ?? true {
                PepBoxState.shared.addItems(from: [url])
            }
        }

        // Show the most recently active download.
        active = downloads.max(by: { $0.modified < $1.modified })?.0

        if downloads.isEmpty {
            pollTimer?.invalidate()
            pollTimer = nil
        } else if pollTimer == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.scan() }
            RunLoop.main.add(timer, forMode: .common)
            pollTimer = timer
        }
    }

    /// "report.pdf.crdownload" → "report.pdf". Chrome's "Unconfirmed 123.crdownload" stays as is.
    static func finalName(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    private static func size(ofBundle url: URL) -> Int64 {
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        var total: Int64 = 0
        while let file = enumerator?.nextObject() as? URL {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    var activityText: String? {
        guard let active else { return nil }
        if let progress = active.progress { return "\(Int((progress * 100).rounded()))%" }
        return ByteCountFormatter.string(fromByteCount: active.bytes, countStyle: .file)
    }
}

struct DownloadsActivityExtension: ExtensionDefinition {
    static let id = "downloadsActivity"
    static let title = "Download Progress"
    static let subtitle = "Browser downloads beside the notch"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .blue
    static let description = "See downloads from Safari, Chrome, Edge, Brave, Arc and Firefox as a live activity beside the notch, then find the finished file waiting on your shelf, ready to drag where it goes. Safari shows a percentage; other browsers show the size so far."
    static let features: [(icon: String, text: String)] = [
        ("arrow.down.circle", "Progress beside the notch"),
        ("tray.and.arrow.down", "Finished files land on the shelf"),
        ("globe", "Works with every major browser")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "arrow.down.circle"
    static let iconPlaceholderColor: Color = .blue
    static func cleanup() { UtilityExtensionKind.downloadsActivity.cleanup() }
}
