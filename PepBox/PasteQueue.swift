//
//  PasteQueue.swift
//  PepBox
//
//  Collect-then-paste: turn the queue on, copy several things, then paste
//  them one after another, in the order you copied them, with a single
//  shortcut. The notch shows how many are left.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

@Observable
final class PasteQueue {
    static let shared = PasteQueue()

    static let toggleKey = "pasteQueue_toggleShortcut"
    static let pasteNextKey = "pasteQueue_pasteNextShortcut"
    static let toggleDefault = SavedShortcut(keyCode: kVK_ANSI_C, modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue)
    static let pasteNextDefault = SavedShortcut(keyCode: kVK_ANSI_V, modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue)

    private(set) var isActive = false
    private(set) var items: [ClipboardItem] = []

    private var toggleHotKey: GlobalHotKey?
    private var pasteHotKey: GlobalHotKey?

    /// Registers the start/stop shortcut (at launch and after the shortcuts change). Paste Next is
    /// only registered while the queue is on, so it doesn't take the keys away from other apps.
    func registerHotKeys() {
        toggleHotKey = nil
        let toggle = ExtensionShortcuts.load(Self.toggleKey, default: Self.toggleDefault)
        toggleHotKey = GlobalHotKey(keyCode: toggle.keyCode, modifiers: toggle.modifiers) { [weak self] in
            DispatchQueue.main.async { self?.toggle() }
        }
        updatePasteHotKey()
    }

    private func updatePasteHotKey() {
        pasteHotKey = nil
        guard isActive else { return }
        let pasteNext = ExtensionShortcuts.load(Self.pasteNextKey, default: Self.pasteNextDefault)
        pasteHotKey = GlobalHotKey(keyCode: pasteNext.keyCode, modifiers: pasteNext.modifiers) { [weak self] in
            DispatchQueue.main.async { self?.pasteNext() }
        }
    }

    func toggle() {
        isActive ? stop() : start()
    }

    func start() {
        items = []
        isActive = true
        updatePasteHotKey()
        HapticFeedback.select()
    }

    func stop() {
        isActive = false
        items = []
        updatePasteHotKey()
    }

    /// Called by the clipboard manager for each new copy.
    func captured(_ item: ClipboardItem) {
        guard isActive, !item.isConcealed else { return }
        items.append(item)
    }

    /// Pastes the oldest queued item into the frontmost app and removes it.
    func pasteNext() {
        guard isActive, !items.isEmpty else {
            NSSound.beep()
            return
        }
        let item = items.removeFirst()
        ClipboardManager.shared.paste(item: item)
        // Our own write: keep it out of history and out of the queue.
        ClipboardManager.shared.ignoreCurrentPasteboardChange()
        if items.isEmpty {
            FlashActivity.shared.show(LiveActivity(id: "queue-done-\(UUID())", icon: "checkmark.circle.fill", tint: .purple,
                                                   text: "Queue empty", progress: nil))
        }
    }

    var liveActivity: LiveActivity? {
        guard isActive else { return nil }
        return LiveActivity(id: "paste-queue", icon: "square.stack.3d.up.fill", tint: .purple,
                            text: items.isEmpty ? "Copy to queue" : "\(items.count) queued", progress: nil)
    }
}
