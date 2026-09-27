import AppKit
import SwiftUI

final class LicenseWindowController: NSObject, NSWindowDelegate {
    static let shared = LicenseWindowController()

    private var window: NSWindow?

    var isVisible: Bool {
        window?.isVisible == true
    }

    private override init() {
        super.init()
    }

    func show() {
        // OPEN SOURCE: License window no longer needed
        // All features are free, so we don't show the activation window
        // Just trigger the completion callback to continue with onboarding if needed
        DispatchQueue.main.async { [weak self] in
            if !UserDefaults.standard.bool(forKey: AppPreferenceKey.hasCompletedOnboarding) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    OnboardingWindowController.shared.show()
                }
            }
        }
    }

    func close() {
        DispatchQueue.main.async { [weak self] in
            self?.window?.close()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // OPEN SOURCE: Always allow closing
        return true
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
