//
//  WhatsNew.swift
//  PepBox
//
//  A one-time "What's New" window after an update, so features that live
//  behind shortcuts get noticed. Bump `revision` when there's something new
//  worth showing; fresh installs see onboarding instead.
//

import SwiftUI
import AppKit

enum WhatsNew {
    static let revision = 1
    private static let seenKey = "whatsNew_seenRevision"

    struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let title: String
        let detail: String
    }

    static let items: [Item] = [
        Item(icon: "magnifyingglass", color: .cyan, title: "Quick Search does more",
             detail: "⌃⌥Space: time zones, dates, colors, timers, define, port 3000, lock, quit apps. Type ? to see it all."),
        Item(icon: "square.stack.3d.up.fill", color: .purple, title: "Clipboard stacks and Paste Queue",
             detail: "Select items in order and paste them together, or ⌃⌥C to collect copies and ⌃⌥V to paste them one by one."),
        Item(icon: "text.insert", color: .orange, title: "Snippets",
             detail: "Type ;date or your own triggers in any app. Right-click clipboard text to save it as a snippet."),
        Item(icon: "sparkle", color: .orange, title: "Agents",
             detail: "Claude Code and Codex progress beside the notch, with a heads-up when they need you."),
        Item(icon: "paperplane.fill", color: .teal, title: "LocalSend and To Phone",
             detail: "Send files to Android and Windows devices on your Wi-Fi, or to any phone with a QR code."),
        Item(icon: "wrench.and.screwdriver", color: .blue, title: "Shelf tools",
             detail: "Right-click a file: resize images, make a GIF, merge PDFs, remove photo location data.")
    ]

    /// Shows the window once per revision for people who have already been through onboarding.
    static func showIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: seenKey) < revision else { return }
        defaults.set(revision, forKey: seenKey)
        guard defaults.bool(forKey: AppPreferenceKey.hasCompletedOnboarding) else { return }
        // Appears without taking focus, so it never swallows what you're typing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { WhatsNewWindowController.shared.show(takingFocus: false) }
    }
}

final class WhatsNewWindowController {
    static let shared = WhatsNewWindowController()
    private var window: NSWindow?

    func show(takingFocus: Bool = true) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingView(rootView: WhatsNewView { [weak self] in self?.close() })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
                              styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.center()
        if takingFocus {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            window.orderFrontRegardless()
        }
        self.window = window
    }

    func close() {
        window?.close()
        window = nil
    }
}

private struct WhatsNewView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("What's New in PepBox")
                    .font(.system(size: 22, weight: .bold))
                Text("A lot has landed since you last looked.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(WhatsNew.items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(item.color)
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(item.color.opacity(0.15)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.system(size: 13, weight: .semibold))
                            Text(item.detail)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Button("Browse Extensions") {
                    onClose()
                    SettingsWindowController.shared.showSettings(tab: .extensions)
                }
                Spacer()
                Button("Got It", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(28)
        .frame(width: 520, height: 560)
    }
}
