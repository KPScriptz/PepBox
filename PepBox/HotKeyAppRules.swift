//
//  HotKeyAppRules.swift
//  PepBox
//
//  "Turn off PepBox shortcuts in these apps": while one of the listed apps is in
//  front, PepBox lets go of its global shortcuts so the keys reach that app
//  (a game, Photoshop, an IDE with its own ⌥Space…).
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

@Observable
final class HotKeyAppRules {
    static let shared = HotKeyAppRules()
    static let key = "hotkeysOffInApps"

    /// Bundle identifiers of the apps where PepBox shortcuts are off.
    private(set) var bundleIDs: [String] = UserDefaults.standard.stringArray(forKey: key) ?? []
    private var observer: NSObjectProtocol?

    /// Called once at launch.
    func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.apply(frontmost: app?.bundleIdentifier)
        }
        apply(frontmost: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }

    func add(_ bundleID: String) {
        guard !bundleIDs.contains(bundleID), bundleID != Bundle.main.bundleIdentifier else { return }
        bundleIDs.append(bundleID)
        save()
    }

    func remove(_ bundleID: String) {
        bundleIDs.removeAll { $0 == bundleID }
        save()
    }

    /// Lets the person pick apps from /Applications.
    func chooseApps() {
        let panel = NSOpenPanel()
        panel.title = "Turn Off PepBox Shortcuts In…"
        panel.prompt = "Add"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier { add(id) }
        }
    }

    private func save() {
        UserDefaults.standard.set(bundleIDs, forKey: Self.key)
        apply(frontmost: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }

    private func apply(frontmost: String?) {
        GlobalHotKey.setPaused(frontmost.map(bundleIDs.contains) ?? false)
    }
}

/// The app list in Settings › Shortcuts.
struct HotKeyAppRulesView: View {
    @State private var rules = HotKeyAppRules.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Turn Off in These Apps")
                    Text("While one of these apps is in front, PepBox's shortcuts go to that app instead.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Add App…") { rules.chooseApps() }
                    .buttonStyle(PepBoxPillButtonStyle(size: .small))
            }
            if rules.bundleIDs.isEmpty {
                Text("No apps yet. PepBox shortcuts work everywhere.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(rules.bundleIDs, id: \.self) { id in
                    HStack(spacing: 10) {
                        Image(nsImage: Self.icon(for: id))
                            .resizable()
                            .frame(width: 22, height: 22)
                        Text(Self.name(for: id))
                        Spacer()
                        Button {
                            rules.remove(id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Turn PepBox shortcuts back on in this app")
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    static func name(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    static func icon(for bundleID: String) -> NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
