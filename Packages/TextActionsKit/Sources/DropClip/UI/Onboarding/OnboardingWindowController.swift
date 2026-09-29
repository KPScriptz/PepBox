// OnboardingWindowController.swift
// DropClip
//
// Manages the NSWindow controller lifecycle for presenting the first-launch onboarding window.
// Uses native macOS window styling (.titled, .fullSizeContentView, traffic lights).
import AppKit
import SwiftUI

@MainActor
public final class OnboardingWindowController: NSWindowController {

    /// Borderless / full-size content windows need to be key so text views and controls work.
    private final class KeyableWindow: NSWindow {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
    }

    public convenience init(onComplete: @escaping @MainActor () -> Void) {
        let window = KeyableWindow(
            // Droppy: 520 tall, not 420. Inside Droppy the welcome opens on the DropClip × Droppy
            // step, which needs about 490 points; at 420 its Continue button was cut off.
            contentRect: NSRect(x: 0, y: 0, width: 520, height: OnboardingView.windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Welcome to Text Actions")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.center()

        self.init(window: window)

        let view = OnboardingView { [weak window] in
            window?.close()
            onComplete()
        }

        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = hosting
    }

    public override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(sender)
    }
}
