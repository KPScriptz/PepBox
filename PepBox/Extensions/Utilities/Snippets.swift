//
//  Snippets.swift
//  PepBox
//
//  Text expansion: type a trigger like ";sig" anywhere and it's replaced with
//  the snippet's text. Placeholders: {date}, {time}, {clipboard}. Uses the
//  Accessibility permission PepBox already has; password fields are never seen
//  (macOS hides secure input from every app).
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

struct Snippet: Codable, Identifiable, Equatable {
    var id = UUID()
    var trigger: String
    var text: String
}

// MARK: - Matching (pure)

struct SnippetEngine {
    private(set) var buffer = ""
    private static let bufferLimit = 64

    /// Adds typed characters one at a time, like live typing, and returns the first snippet whose
    /// trigger the typing ends with. (So a trigger that starts another, like ";sig" and ";sig2",
    /// always fires first; the options screen says to avoid that.)
    mutating func type(_ characters: String, snippets: [Snippet]) -> Snippet? {
        for character in characters {
            if character == "\u{7F}" || character == "\u{08}" {  // delete / backspace
                if !buffer.isEmpty { buffer.removeLast() }
                continue
            }
            buffer.append(character)
            if buffer.count > Self.bufferLimit { buffer.removeFirst(buffer.count - Self.bufferLimit) }
            // If two triggers end here (";d" and "x;d"), the longer one is the more specific.
            if let match = snippets.filter({ !$0.trigger.isEmpty && buffer.hasSuffix($0.trigger) })
                .max(by: { $0.trigger.count < $1.trigger.count }) {
                buffer = ""
                return match
            }
        }
        return nil
    }

    /// Clicking, switching apps or arrow keys move the caret, so what came before no longer counts.
    mutating func reset() { buffer = "" }

    static func expand(_ text: String, now: Date = Date(), clipboard: String? = nil, locale: Locale = .current) -> String {
        let date = DateFormatter()
        date.locale = locale
        date.dateStyle = .medium
        date.timeStyle = .none
        let time = DateFormatter()
        time.locale = locale
        time.dateStyle = .none
        time.timeStyle = .short
        return text
            .replacingOccurrences(of: "{date}", with: date.string(from: now))
            .replacingOccurrences(of: "{time}", with: time.string(from: now))
            .replacingOccurrences(of: "{clipboard}", with: clipboard ?? "")
    }
}

// MARK: - Controller

final class SnippetController {
    static let shared = SnippetController()
    static let storeKey = "snippets_list"

    private var monitor: Any?
    private var mouseMonitor: Any?
    private var engine = SnippetEngine()
    private var isExpanding = false

    static var snippets: [Snippet] {
        get {
            guard let data = UserDefaults.standard.data(forKey: storeKey),
                  let list = try? JSONDecoder().decode([Snippet].self, from: data) else { return defaults }
            return list
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: storeKey)
        }
    }

    static let defaults: [Snippet] = [
        Snippet(trigger: ";date", text: "{date}"),
        Snippet(trigger: ";time", text: "{time}"),
        Snippet(trigger: ";shrug", text: "¯\\_(ツ)_/¯")
    ]

    func setEnabled(_ enabled: Bool) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        monitor = nil
        mouseMonitor = nil
        engine.reset()
        guard enabled else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in self?.handle(event) }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.engine.reset()
        }
    }

    private func handle(_ event: NSEvent) {
        guard !isExpanding else { return }
        let navigation: Set<Int> = [kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow, kVK_Return, kVK_Tab, kVK_Escape, kVK_Home, kVK_End]
        if !event.modifierFlags.intersection([.command, .control]).isEmpty || navigation.contains(Int(event.keyCode)) {
            engine.reset()
            return
        }
        let characters = event.keyCode == UInt16(kVK_Delete) ? "\u{7F}" : (event.characters ?? "")
        guard let snippet = engine.type(characters, snippets: Self.snippets) else { return }
        expand(snippet)
    }

    /// Deletes the trigger with backspaces, then pastes the expansion and restores the clipboard.
    private func expand(_ snippet: Snippet) {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)
        let text = SnippetEngine.expand(snippet.text, clipboard: previous)
        isExpanding = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let source = CGEventSource(stateID: .hidSystemState)
            for _ in 0..<snippet.trigger.count {
                Self.post(kVK_Delete, flags: [], source: source)
            }
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
            ClipboardManager.shared.ignoreCurrentPasteboardChange()
            Self.post(kVK_ANSI_V, flags: .maskCommand, source: source)

            // Put back what was on the clipboard once the paste has landed.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                pasteboard.clearContents()
                if let previous { pasteboard.setString(previous, forType: .string) }
                ClipboardManager.shared.ignoreCurrentPasteboardChange()
                self.isExpanding = false
            }
        }
    }

    private static func post(_ key: Int, flags: CGEventFlags, source: CGEventSource?) {
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(key), keyDown: down)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }
}

// MARK: - Options UI

struct SnippetsOptions: View {
    @State private var snippets = SnippetController.snippets

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($snippets) { $snippet in
                HStack(alignment: .top, spacing: 8) {
                    TextField("Trigger", text: $snippet.trigger)
                        .frame(width: 90)
                        .font(.system(.body, design: .monospaced))
                    TextField("Expands to", text: $snippet.text, axis: .vertical)
                        .lineLimit(1...4)
                    Button {
                        snippets.removeAll { $0.id == snippet.id }
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            Button {
                snippets.append(Snippet(trigger: ";", text: ""))
            } label: {
                Label("Add Snippet", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            Text("Start triggers with ; so normal typing never sets them off, and don't make one trigger the start of another. Placeholders: {date}, {time}, {clipboard}.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: snippets) { _, value in SnippetController.snippets = value }
    }
}

struct SnippetsExtension: ExtensionDefinition {
    static let id = "snippets"
    static let title = "Snippets"
    static let subtitle = "Type a shortcut, get the full text"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .orange
    static let description = "Type a trigger like ;sig or ;addr in any app and it turns into the full text: your signature, address, a canned reply. Snippets can include today's date, the time or what's on your clipboard. Your clipboard is put back afterwards, and password fields are never read."
    static let features: [(icon: String, text: String)] = [
        ("text.insert", "Works in every app"),
        ("calendar", "{date}, {time} and {clipboard} placeholders"),
        ("lock.shield", "Password fields are never seen")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "text.insert"
    static let iconPlaceholderColor: Color = .orange
    static func cleanup() { UtilityExtensionKind.snippets.cleanup() }
}
