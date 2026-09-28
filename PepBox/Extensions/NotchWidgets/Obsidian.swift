//
//  Obsidian.swift
//  PepBox
//
//  Recent notes from an Obsidian vault, plus quick capture into an inbox note.
//

import SwiftUI
import AppKit

struct ObsidianNote: Identifiable, Hashable {
    let url: URL
    let modified: Date
    var id: String { url.path }
    var title: String { url.deletingPathExtension().lastPathComponent }
}

@Observable
final class ObsidianManager {
    static let shared = ObsidianManager()

    private static let vaultKey = "obsidian_vaultPath"
    static let inboxName = "PepBox Inbox.md"

    private(set) var vault: URL?
    private(set) var notes: [ObsidianNote] = []
    var query = ""

    var filteredNotes: [ObsidianNote] {
        let text = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list = text.isEmpty ? notes : notes.filter { $0.title.lowercased().contains(text) }
        return Array(list.prefix(30))
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Self.vaultKey) {
            vault = URL(fileURLWithPath: saved)
        } else {
            vault = Self.detectVault()
        }
    }

    /// Reads Obsidian's own vault list and picks the open (or most recently used) vault.
    static func detectVault(configURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/obsidian/obsidian.json")) -> URL? {
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let vaults = json["vaults"] as? [String: [String: Any]] else { return nil }
        let entries = vaults.values.compactMap { entry -> (path: String, open: Bool, ts: Double)? in
            guard let path = entry["path"] as? String else { return nil }
            return (path, entry["open"] as? Bool ?? false, (entry["ts"] as? NSNumber)?.doubleValue ?? 0)
        }
        let best = entries.sorted { lhs, rhs in lhs.open != rhs.open ? lhs.open : lhs.ts > rhs.ts }.first
        return best.map { URL(fileURLWithPath: $0.path) }
    }

    func chooseVault() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Use Vault"
        panel.message = "Choose your Obsidian vault folder"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        vault = url
        UserDefaults.standard.set(url.path, forKey: Self.vaultKey)
        refresh()
    }

    /// Markdown notes in the vault, newest first (skips .obsidian and .trash).
    func refresh() {
        guard let vault else { notes = []; return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
            let enumerator = FileManager.default.enumerator(
                at: vault, includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
            var found: [ObsidianNote] = []
            while let url = enumerator?.nextObject() as? URL {
                guard url.pathExtension.lowercased() == "md",
                      let values = try? url.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true else { continue }
                found.append(ObsidianNote(url: url, modified: values.contentModificationDate ?? .distantPast))
                if found.count > 5_000 { break }
            }
            found.sort { $0.modified > $1.modified }
            DispatchQueue.main.async { self?.notes = found }
        }
    }

    func open(_ note: ObsidianNote) {
        var components = URLComponents(string: "obsidian://open")
        components?.queryItems = [URLQueryItem(name: "path", value: note.url.path)]
        if let url = components?.url, NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(note.url)  // Obsidian not installed: open with the default app
        }
    }

    /// Appends a timestamped line to the inbox note (created if needed). Returns false without a vault.
    @discardableResult
    func capture(_ text: String) -> Bool {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let vault, !line.isEmpty else { return false }
        let inbox = vault.appendingPathComponent(Self.inboxName)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let entry = "- \(formatter.string(from: Date())) \(line)\n"
        if let handle = try? FileHandle(forWritingTo: inbox) {
            handle.seekToEndOfFile()
            handle.write(Data(entry.utf8))
            try? handle.close()
        } else {
            try? ("# PepBox Inbox\n\n" + entry).write(to: inbox, atomically: true, encoding: .utf8)
        }
        refresh()
        return true
    }
}

struct ObsidianNotchView: View {
    @Bindable var manager: ObsidianManager
    @State private var capture = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if manager.vault == nil {
                HStack {
                    Text("No Obsidian vault found.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                    Button("Choose Vault") { manager.chooseVault() }
                        .controlSize(.small)
                }
            } else {
                HStack(spacing: 8) {
                    field("Capture to Inbox…", text: $capture, icon: "square.and.pencil") {
                        if manager.capture(capture) { capture = "" }
                    }
                    field("Find note", text: $manager.query, icon: "magnifyingglass") {
                        if let first = manager.filteredNotes.first { manager.open(first) }
                    }
                    .frame(width: 150)
                }
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(manager.filteredNotes) { note in
                            Button { manager.open(note) } label: {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundStyle(.purple)
                                    Text(note.title)
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(note.modified, style: .relative)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .font(.system(size: 12))
                                .padding(.vertical, 3)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onAppear { manager.refresh() }
    }

    private func field(_ placeholder: String, text: Binding<String>, icon: String, onSubmit: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.white.opacity(0.5))
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .onSubmit(onSubmit)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(.white.opacity(0.08)))
    }
}
