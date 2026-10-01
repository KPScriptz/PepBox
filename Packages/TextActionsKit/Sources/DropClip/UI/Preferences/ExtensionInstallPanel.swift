// ExtensionInstallPanel.swift
// DropClip
//
// Shared "Install File…" NSOpenPanel presenter for the extension store and installed
// extensions views. The open panel is the one dialog the settings window still shows. Split out of ExtensionsStoreView.swift.
import AppKit
import DropClipCore

/// Presents an open panel for picking a `.dropclipext` folder, `.zip`, or script file and
/// installs it via `ExtensionManager`, posting the extensions-did-change notification on success.
@MainActor
func presentInstallExtensionPanel() {
    let panel = NSOpenPanel()
    panel.title = String(localized: "Select Extension to Install")
    panel.message = String(localized: "Choose a .dropclipext folder, .zip archive, or script file")
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = true
    panel.canChooseFiles = true
    panel.treatsFilePackagesAsDirectories = true
    panel.allowedContentTypes = []

    panel.begin { response in
        guard response == .OK, let selectedURL = panel.url else { return }
        Task {
            do {
                _ = try await ExtensionManager.shared.installExtension(from: selectedURL, source: ExtensionSource.package.rawValue)
                await MainActor.run {
                    NotificationCenter.default.post(name: .init("DropClipExtensionsDidChange"), object: nil)
                }
            } catch {
                await MainActor.run {
                    // The settings window reports failures inline rather than in a modal alert.
                    SettingsRouter.shared.notifyError(
                        title: String(localized: "Extension Install Failed"),
                        message: error.localizedDescription
                    )
                }
            }
        }
    }
}
