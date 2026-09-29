//
//  ScreenTextGrabber.swift
//  PepBox
//
//  Select any area of the screen and its text is copied (on-device OCR).
//  Uses macOS's own "area to clipboard" screenshot (⌃⇧⌘4), so PepBox needs
//  no Screen Recording permission, only Accessibility to press the keys.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

enum ScreenTextGrabber {
    private static var pollTimer: Timer?

    static func start() {
        guard AXIsProcessTrusted() else {
            PermissionManager.shared.requestAccessibilityForUserAction()
            return
        }
        pollTimer?.invalidate()
        let pasteboard = NSPasteboard.general
        let startCount = pasteboard.changeCount
        let deadline = Date().addingTimeInterval(60)

        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_4), keyDown: keyDown) else { continue }
            event.flags = [.maskCommand, .maskShift, .maskControl]
            event.post(tap: .cghidEventTap)
        }

        // Wait for the capture to land on the clipboard (or give up after a minute / Esc).
        let timer = Timer(timeInterval: 0.2, repeats: true) { timer in
            if Date() > deadline {
                timer.invalidate()
                return
            }
            guard pasteboard.changeCount != startCount else { return }
            timer.invalidate()
            guard let image = NSImage(pasteboard: pasteboard) else { return }
            Task {
                let text = (try? await OCRService.shared.performOCR(on: image)) ?? ""
                await MainActor.run { finish(with: text) }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    @MainActor
    private static func finish(with text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            FlashActivity.shared.show(LiveActivity(id: "ocr-none", icon: "text.viewfinder", tint: .gray, text: "No text found", progress: nil))
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(trimmed, forType: .string)
        HapticFeedback.copy()
        let words = trimmed.split(whereSeparator: { $0.isWhitespace }).count
        FlashActivity.shared.show(LiveActivity(id: "ocr-\(UUID())", icon: "text.viewfinder", tint: .teal,
                                               text: "Copied \(words) word\(words == 1 ? "" : "s")", progress: nil))
    }
}

/// A live activity shown for a couple of seconds as feedback ("Copied 42 words").
@Observable
final class FlashActivity {
    static let shared = FlashActivity()

    private(set) var activity: LiveActivity?
    private var hideWork: DispatchWorkItem?

    func show(_ activity: LiveActivity, for seconds: TimeInterval = 2.5) {
        self.activity = activity
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.activity = nil }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}
