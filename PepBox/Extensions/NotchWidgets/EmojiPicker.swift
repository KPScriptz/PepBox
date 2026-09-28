//
//  EmojiPicker.swift
//  PepBox
//
//  Searchable emoji grid. Clicking an emoji types it into the frontmost app
//  (or copies it when Accessibility isn't granted).
//

import SwiftUI
import AppKit

struct EmojiEntry: Hashable {
    let emoji: String
    let name: String
}

enum EmojiCatalog {
    /// Every single-scalar emoji macOS knows, named from Unicode character data.
    static let all: [EmojiEntry] = {
        let ranges: [ClosedRange<UInt32>] = [0x2600...0x27BF, 0x2B00...0x2BFF, 0x1F300...0x1FAFF]
        let skinTones: ClosedRange<UInt32> = 0x1F3FB...0x1F3FF
        let regionalIndicators: ClosedRange<UInt32> = 0x1F1E6...0x1F1FF
        var entries: [EmojiEntry] = []
        for range in ranges {
            for value in range where !skinTones.contains(value) && !regionalIndicators.contains(value) {
                guard let scalar = Unicode.Scalar(value), scalar.properties.isEmoji,
                      let name = scalar.properties.name?.lowercased() else { continue }
                if scalar.properties.isEmojiPresentation {
                    entries.append(EmojiEntry(emoji: String(scalar), name: name))
                } else if value < 0x2C00 {
                    // Text-style symbols like ❤ need the emoji variation selector.
                    entries.append(EmojiEntry(emoji: String(scalar) + "\u{FE0F}", name: name))
                }
            }
        }
        return entries
    }()

    private static let recentsKey = "emojiPicker_recents"

    static var recents: [String] {
        UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
    }

    static func noteUsed(_ emoji: String) {
        var list = recents.filter { $0 != emoji }
        list.insert(emoji, at: 0)
        UserDefaults.standard.set(Array(list.prefix(16)), forKey: recentsKey)
    }
}

enum EmojiInserter {
    /// Last app other than PepBox that was frontmost: where the emoji should go.
    private static var lastExternalApp: NSRunningApplication?
    private static var activationObserver: NSObjectProtocol?

    /// Starts remembering the user's app (called when the picker appears).
    static func trackTargetApp() {
        remember(NSWorkspace.shared.frontmostApplication)
        guard activationObserver == nil else { return }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            remember(note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
        }
    }

    private static func remember(_ app: NSRunningApplication?) {
        guard let app, app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        lastExternalApp = app
    }

    /// Types the emoji into the frontmost app; falls back to copying it.
    /// Returns true if it was typed, false if it was copied.
    @discardableResult
    static func insert(_ emoji: String) -> Bool {
        EmojiCatalog.noteUsed(emoji)
        guard AXIsProcessTrusted() else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(emoji, forType: .string)
            return false
        }
        // Give keyboard focus back to the app the user was typing in (the shelf's
        // search field may have taken it), then type the emoji there.
        lastExternalApp?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let utf16 = Array(emoji.utf16)
            for keyDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: keyDown) else { continue }
                utf16.withUnsafeBufferPointer { buffer in
                    event.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
                }
                event.post(tap: .cghidEventTap)
            }
        }
        return true
    }
}

struct EmojiPickerNotchView: View {
    @State private var query = ""
    @State private var recents = EmojiCatalog.recents
    @State private var copiedEmoji: String?

    private var results: [EmojiEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return EmojiCatalog.all }
        return EmojiCatalog.all.filter { $0.name.contains(trimmed) }
    }

    private let columns = Array(repeating: GridItem(.fixed(30), spacing: 4), count: 14)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.5))
                TextField("Search emoji", text: $query)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                if let copiedEmoji {
                    Text("\(copiedEmoji) copied")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .transition(.opacity)
                }
            }
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.08)))

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                    if query.isEmpty {
                        ForEach(recents, id: \.self) { emoji in
                            emojiButton(emoji, help: "Recently used")
                        }
                    }
                    ForEach(results, id: \.self) { entry in
                        emojiButton(entry.emoji, help: entry.name.capitalized)
                    }
                }
            }
        }
        .onAppear { EmojiInserter.trackTargetApp() }
    }

    private func emojiButton(_ emoji: String, help: String) -> some View {
        Button {
            let typed = EmojiInserter.insert(emoji)
            recents = EmojiCatalog.recents
            if !typed {
                withAnimation { copiedEmoji = emoji }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { if copiedEmoji == emoji { copiedEmoji = nil } }
                }
            }
        } label: {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
