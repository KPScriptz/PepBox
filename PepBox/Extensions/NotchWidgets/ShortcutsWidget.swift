//
//  ShortcutsWidget.swift
//  PepBox
//
//  Run Apple Shortcuts from the shelf, and drop files on one to use them as
//  its input. Uses the system `shortcuts` command, so nothing to set up.
//

import SwiftUI
import UniformTypeIdentifiers

@Observable
final class ShortcutsWidgetManager {
    static let shared = ShortcutsWidgetManager()

    private static let pinnedKey = "shortcutsWidget_pinned"
    private static let tool = "/usr/bin/shortcuts"

    enum RunState: Equatable { case running, done, failed(String) }

    private(set) var all: [String] = []
    private(set) var pinned: [String] = UserDefaults.standard.stringArray(forKey: pinnedKey) ?? []
    private(set) var states: [String: RunState] = [:]

    /// Pinned shortcuts, or the first few in the library until you pin some.
    var shown: [String] {
        let existing = pinned.filter { all.isEmpty || all.contains($0) }
        return existing.isEmpty ? Array(all.prefix(8)) : existing
    }

    func reload() {
        Task.detached {
            let output = Self.run([ "list" ]).output
            let names = output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            await MainActor.run { self.all = names }
        }
    }

    func togglePin(_ name: String) {
        if let index = pinned.firstIndex(of: name) { pinned.remove(at: index) } else { pinned.append(name) }
        UserDefaults.standard.set(pinned, forKey: Self.pinnedKey)
    }

    func run(_ name: String, files: [URL] = []) {
        guard states[name] != .running else { return }
        states[name] = .running
        var arguments = ["run", name]
        for file in files { arguments += ["--input-path", file.path] }
        Task.detached {
            let result = Self.run(arguments)
            await MainActor.run {
                self.states[name] = result.status == 0 ? .done : .failed(result.error.isEmpty ? "Failed" : result.error)
            }
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                if self.states[name] != .running { self.states[name] = nil }
            }
        }
    }

    func openShortcutsApp(editing name: String? = nil) {
        if let name, let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "shortcuts://open-shortcut?name=\(encoded)") {
            NSWorkspace.shared.open(url)
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.shortcuts") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func run(_ arguments: [String]) -> (status: Int32, output: String, error: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do { try process.run() } catch { return (-1, "", error.localizedDescription) }
        let output = out.fileHandleForReading.readDataToEndOfFile()
        let errorData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus,
                String(decoding: output, as: UTF8.self),
                String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

struct ShortcutsNotchView: View {
    var manager: ShortcutsWidgetManager

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(manager.pinned.isEmpty ? "Shortcuts" : "Pinned Shortcuts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Menu {
                    ForEach(manager.all, id: \.self) { name in
                        Button {
                            manager.togglePin(name)
                        } label: {
                            if manager.pinned.contains(name) { Label(name, systemImage: "checkmark") } else { Text(name) }
                        }
                    }
                    Divider()
                    Button("Open Shortcuts") { manager.openShortcutsApp() }
                } label: {
                    Image(systemName: "pin")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Choose which shortcuts to show")
            }

            if manager.shown.isEmpty {
                Text("No shortcuts yet. Make one in the Shortcuts app.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(manager.shown, id: \.self) { name in
                        ShortcutTile(name: name, state: manager.states[name], manager: manager)
                    }
                }
            }
        }
        .onAppear { manager.reload() }
    }
}

private struct ShortcutTile: View {
    let name: String
    let state: ShortcutsWidgetManager.RunState?
    let manager: ShortcutsWidgetManager
    @State private var isTargeted = false
    @State private var isHovering = false

    var body: some View {
        Button { manager.run(name) } label: {
            HStack(spacing: 6) {
                statusIcon
                    .frame(width: 14)
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(isTargeted ? 0.25 : (isHovering ? 0.14 : 0.08)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isTargeted ? Color.indigo : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(helpText)
        .contextMenu {
            Button("Run") { manager.run(name) }
            Button("Edit in Shortcuts") { manager.openShortcutsApp(editing: name) }
            Button(manager.pinned.contains(name) ? "Unpin" : "Pin") { manager.togglePin(name) }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            Task {
                var urls: [URL] = []
                for provider in providers {
                    if let url = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) as? Data,
                       let fileURL = URL(dataRepresentation: url, relativeTo: nil) {
                        urls.append(fileURL)
                    }
                }
                guard !urls.isEmpty else { return }
                await MainActor.run { manager.run(name, files: urls) }
            }
            return true
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .running: ProgressView().controlSize(.mini)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case nil: Image(systemName: "square.2.layers.3d.fill").foregroundStyle(.indigo)
        }
    }

    private var helpText: String {
        if case .failed(let message) = state { return message }
        return "Run \(name) · drop files to use them as input"
    }
}
