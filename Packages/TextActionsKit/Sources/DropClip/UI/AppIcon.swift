// AppIcon.swift
// DropClip
//
// Loads the app icon directly from the bundle's AppIcon.icns so UI surfaces always
// render the custom icon. NSApp.applicationIconImage can fall back to the generic
// placeholder for agent (LSUIElement) apps; reading the resource avoids that path.
import AppKit
import DropClipCore

@MainActor
enum AppIcon {
    static var image: NSImage {
        if let icon = Bundle.dropclip.image(forResource: "AppIcon") {
            return icon
        }
        // Droppy: the droplet's icon is compiled under its own name (`CFBundleIconFile`), and
        // `NSApp.applicationIconImage` is Droppy's.
        if let name = Bundle.dropclip.infoDictionary?["CFBundleIconFile"] as? String,
           let icon = Bundle.dropclip.image(forResource: name) {
            return icon
        }
        return NSApp.applicationIconImage
    }
}
