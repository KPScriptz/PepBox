//
//  DropClipAppLookup.swift
//  DropClip, inside Droppy
//
//  An application's location, name and icon, looked up once.
//

import AppKit

/// Droppy: the App rules rows and the application picker asked LaunchServices for an app's URL
/// (a round trip to another process), opened its bundle and fetched its icon inside `body`, for
/// every row, on every pass: a keystroke in the picker's search repeated it for a few hundred
/// apps. Asked once, the answer is kept for the session; an app's location and icon do not
/// change while Settings is open.
@MainActor
enum DropClipAppLookup {
    private static var urls: [String: URL?] = [:]
    private static var names: [String: String?] = [:]
    private static var icons: [String: NSImage] = [:]

    static func url(forBundleID bundleID: String) -> URL? {
        if let known = urls[bundleID] { return known }
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        urls[bundleID] = url
        return url
    }

    /// The app's own name (`CFBundleName`, then `CFBundleDisplayName`), or nil when it is not
    /// installed.
    static func name(forBundleID bundleID: String) -> String? {
        if let known = names[bundleID] { return known }
        var name: String?
        if let url = url(forBundleID: bundleID), let bundle = Bundle(url: url) {
            name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        }
        names[bundleID] = name
        return name
    }

    /// The app's icon, or nil when it is not installed.
    static func icon(forBundleID bundleID: String) -> NSImage? {
        if let known = icons[bundleID] { return known }
        guard let url = url(forBundleID: bundleID) else { return nil }
        return icon(forPath: url.path, key: bundleID)
    }

    /// The icon of the app at `path`, kept under `key`.
    static func icon(forPath path: String, key: String) -> NSImage {
        if let known = icons[key] { return known }
        let icon = NSWorkspace.shared.icon(forFile: path)
        icons[key] = icon
        return icon
    }
}
