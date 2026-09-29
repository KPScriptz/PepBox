//
//  TextActions.swift
//  PepBox
//
//  A small action bar that appears after selecting text in any app. The
//  selection is read through Accessibility, so the clipboard isn't touched.
//

import SwiftUI
import AppKit
import AVFoundation

final class TextActionsController {
    static let shared = TextActionsController()

    private var mouseDownMonitor: Any?
    private var mouseUpMonitor: Any?
    private var keyMonitor: Any?
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    private var mouseDownLocation: NSPoint = .zero
    private let speech = AVSpeechSynthesizer()

    /// Chromium and Electron apps only expose selected text once asked to.
    private var enabledManualAccessibility = Set<pid_t>()

    func setEnabled(_ enabled: Bool) {
        if enabled {
            guard mouseUpMonitor == nil else { return }
            mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
                self?.mouseDownLocation = NSEvent.mouseLocation
                self?.hide()
            }
            mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
                self?.mouseUp(event)
            }
            keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
                self?.hide()
            }
        } else {
            [mouseDownMonitor, mouseUpMonitor, keyMonitor].compactMap { $0 }.forEach(NSEvent.removeMonitor)
            mouseDownMonitor = nil
            mouseUpMonitor = nil
            keyMonitor = nil
            hide()
        }
    }

    private func mouseUp(_ event: NSEvent) {
        let location = NSEvent.mouseLocation
        let dragged = hypot(location.x - mouseDownLocation.x, location.y - mouseDownLocation.y) > 6
        guard dragged || event.clickCount >= 2, AXIsProcessTrusted() else { return }
        // Give the app a moment to update its selection.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, let text = self.selectedText(), !text.isEmpty else { return }
            self.show(text: text, at: location)
        }
    }

    private func selectedText() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        // This runs on the main thread: don't let a hung app freeze PepBox (default is ~6 s).
        // Setting it on the system-wide element makes it the default for every element we query.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.25)
        if !enabledManualAccessibility.contains(app.processIdentifier) {
            enabledManualAccessibility.insert(app.processIdentifier)
            AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        }

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused else { return nil }
        let element = focused as! AXUIElement

        // Never act on password fields.
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &role)
        if (role as? String) == kAXSecureTextFieldSubrole { return nil }

        var selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected) == .success,
              let text = selected as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count <= 10_000 ? trimmed : nil
    }

    private func show(text: String, at point: NSPoint) {
        hide()
        let actions = TextActionsView(text: text) { [weak self] action in
            self?.perform(action, on: text)
            self?.hide()
        }
        let hosting = NSHostingView(rootView: actions)
        let size = hosting.fittingSize
        var origin = NSPoint(x: point.x - size.width / 2, y: point.y + 14)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) {
            let frame = screen.visibleFrame
            origin.x = min(max(origin.x, frame.minX + 4), frame.maxX - size.width - 4)
            if origin.y + size.height > frame.maxY { origin.y = point.y - size.height - 14 }
        }

        let panel = NSPanel(contentRect: NSRect(origin: origin, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting
        panel.orderFrontRegardless()
        self.panel = panel

        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    func hide() {
        hideWork?.cancel()
        hideWork = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func perform(_ action: TextAction, on text: String) {
        switch action {
        case .copy:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            HapticFeedback.copy()
        case .search:
            open("https://www.google.com/search?q=", text)
        case .translate:
            open("https://translate.google.com/?sl=auto&op=translate&text=", text)
        case .define:
            open("dict://", text)
        case .speak:
            speech.stopSpeaking(at: .immediate)
            speech.speak(AVSpeechUtterance(string: text))
        case .shelf:
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PepBoxTextClips", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let title = text.prefix(40).components(separatedBy: .newlines).first?
                .replacingOccurrences(of: "/", with: "-")
                .trimmingCharacters(in: .whitespaces) ?? "Text"
            let url = folder.appendingPathComponent("\(title.isEmpty ? "Text" : title).txt")
            try? text.write(to: url, atomically: true, encoding: .utf8)
            PepBoxState.shared.addItems(from: [url])
        }
    }

    private func open(_ prefix: String, _ text: String) {
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: prefix + encoded) else { return }
        NSWorkspace.shared.open(url)
    }
}

enum TextAction: CaseIterable {
    case copy, search, translate, define, speak, shelf

    var icon: String {
        switch self {
        case .copy: return "doc.on.doc"
        case .search: return "magnifyingglass"
        case .translate: return "character.bubble"
        case .define: return "book"
        case .speak: return "speaker.wave.2"
        case .shelf: return "tray.and.arrow.down"
        }
    }

    var title: String {
        switch self {
        case .copy: return "Copy"
        case .search: return "Search"
        case .translate: return "Translate"
        case .define: return "Define"
        case .speak: return "Speak"
        case .shelf: return "To Shelf"
        }
    }
}

struct TextActionsView: View {
    let text: String
    let onAction: (TextAction) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(TextAction.allCases, id: \.self) { action in
                Button { onAction(action) } label: {
                    Image(systemName: action.icon)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 30, height: 26)
                }
                .buttonStyle(.plain)
                .help(action.title)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15)))
    }
}
