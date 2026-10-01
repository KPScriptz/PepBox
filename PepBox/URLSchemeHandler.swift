//
//  URLSchemeHandler.swift
//  PepBox
//
//  Created by Jordy Spruit on 08/01/2026.
//

import SwiftUI

/// Handles incoming pepbox:// URL scheme requests from Alfred and other apps
///
/// URL Format:
/// - pepbox://add?target=shelf&path=/path/to/file1&path=/path/to/file2
/// - pepbox://add?target=basket&path=/path/to/file
/// - pepbox://extension/{id} - Opens extension info sheet
///
/// Parameters:
/// - target: "shelf" or "basket" - where to add the files
/// - path: URL-encoded file path (can repeat for multiple files)
struct URLSchemeHandler {
    
    /// Handles an incoming pepbox:// URL
    /// - Parameter url: The URL to process
    static func handle(_ url: URL) {
        print("🔗 URLSchemeHandler: Received URL: \(url.absoluteString)")

        let licenseManager = LicenseManager.shared
        if licenseManager.requiresLicenseEnforcement && !licenseManager.isActivated {
            print("🔒 URLSchemeHandler: Blocked while license is not active")
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                LicenseWindowController.shared.show()
            }
            return
        }
        
        // Parse the action from the host component (e.g., "add")
        guard let host = url.host else {
            print("⚠️ URLSchemeHandler: No action specified in URL")
            return
        }
        
        switch host.lowercased() {
        case "add":
            handleAddAction(url: url)
        case "spotify-callback":
            // Handle Spotify OAuth callback
            handleSpotifyCallback(url: url)
        case "extension":
            // Open extension info sheet from website
            handleExtensionAction(url: url)
        case "qa-snapshot":
            // Layout testing only: pepbox://qa-snapshot?tab=general&width=820&height=3000&out=/tmp/x.png
            guard UserDefaults.standard.bool(forKey: "qaSnapshotsEnabled"),
                  let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return }
            func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
            guard let name = value("tab")?.lowercased(),
                  let tab = SettingsTab.allCases.first(where: { $0.rawValue.lowercased() == name || $0.title.lowercased() == name }),
                  let out = value("out") else { return }
            let width = CGFloat(Double(value("width") ?? "") ?? 920)
            let height = CGFloat(Double(value("height") ?? "") ?? 3000)
            DispatchQueue.main.async {
                SettingsWindowController.shared.snapshot(tab: tab, width: width, height: height, to: URL(fileURLWithPath: out))
            }
        case "qa-widget":
            // Layout testing only: pepbox://qa-widget?kind=calculator&out=/tmp/x.png
            guard UserDefaults.standard.bool(forKey: "qaSnapshotsEnabled"),
                  let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                  let kind = items.first(where: { $0.name == "kind" })?.value.flatMap(NotchWidgetKind.init(rawValue:)),
                  let out = items.first(where: { $0.name == "out" })?.value else { return }
            DispatchQueue.main.async {
                SettingsWindowController.shared.snapshotView(
                    NotchWidgetPanel(kind: kind).frame(width: 560, height: 190).background(Color.black).environment(\.colorScheme, .dark),
                    size: NSSize(width: 560, height: 190), to: URL(fileURLWithPath: out))
            }
        case "qa-convert", "qa-ring":
            // Testing only. pepbox://qa-convert?target=image.png&file=/a.heic&file=/b.heic&out=/tmp/r.txt runs a
            // Convert Ring target; pepbox://qa-ring?file=/a.heic&tools=1&highlight=2&out=/tmp/ring.png draws the ring.
            guard UserDefaults.standard.bool(forKey: "qaSnapshotsEnabled"),
                  let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                  let out = items.first(where: { $0.name == "out" })?.value else { return }
            let files = items.filter { $0.name == "file" }.compactMap(\.value).map { URL(fileURLWithPath: $0) }
            let extensions = files.map(\.pathExtension)
            let ffmpeg = ConvertRingEngine.ffmpegPath != nil
            let tools = items.contains { $0.name == "tools" && $0.value == "1" }
            if host == "qa-ring" {
                let model = ConvertRingModel()
                model.tools = tools
                model.count = files.count
                model.targets = tools ? ConvertRing.toolTargets(for: extensions) : ConvertRing.formatTargets(for: extensions, ffmpeg: ffmpeg)
                model.highlighted = items.first(where: { $0.name == "highlight" })?.value.flatMap(Int.init)
                DispatchQueue.main.async {
                    SettingsWindowController.shared.snapshotView(
                        ConvertRingView(model: model).background(Color(white: 0.35)),
                        size: NSSize(width: 300, height: 300), to: URL(fileURLWithPath: out))
                }
                return
            }
            let all = ConvertRing.formatTargets(for: extensions, ffmpeg: ffmpeg) + ConvertRing.toolTargets(for: extensions)
            guard let id = items.first(where: { $0.name == "target" })?.value,
                  let target = all.first(where: { $0.id == id }) else {
                try? ("no target; offered: " + all.map(\.id).joined(separator: " ")).write(toFile: out, atomically: true, encoding: .utf8)
                return
            }
            Task {
                let result = await ConvertRingEngine.run(target, on: files)
                let report = (result.outputs.map(\.path) + ["failures=\(result.failures)", "message=\(result.message ?? "")"]).joined(separator: "\n")
                try? report.write(toFile: out, atomically: true, encoding: .utf8)
            }
        case "settings":
            // pepbox://settings/clipboard (or ?tab=clipboard) opens Settings on that tab
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let name = (components?.queryItems?.first { $0.name == "tab" }?.value ?? url.lastPathComponent).lowercased()
            DispatchQueue.main.async {
                if let tab = SettingsTab.allCases.first(where: { $0.rawValue.lowercased() == name || $0.title.lowercased() == name }) {
                    SettingsWindowController.shared.showSettings(tab: tab)
                } else {
                    SettingsWindowController.shared.showSettings()
                }
            }
        default:
            print("⚠️ URLSchemeHandler: Unknown action '\(host)'")
        }
    }
    
    /// Handles the "add" action - adds files to shelf or basket
    private static func handleAddAction(url: URL) {
        // Parse query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("⚠️ URLSchemeHandler: Failed to parse URL components")
            return
        }
        
        let queryItems = components.queryItems ?? []
        
        // Get target (shelf or basket, default to shelf)
        let target = queryItems.first(where: { $0.name == "target" })?.value ?? "shelf"
        
        // Get all file paths
        let paths = queryItems
            .filter { $0.name == "path" }
            .compactMap { $0.value }
            .map { URL(fileURLWithPath: $0) }
        
        guard !paths.isEmpty else {
            print("⚠️ URLSchemeHandler: No file paths provided")
            return
        }
        
        print("🔗 URLSchemeHandler: Adding \(paths.count) file(s) to \(target)")
        
        // Add files to the appropriate destination
        let state = PepBoxState.shared
        
        switch target.lowercased() {
        case "basket":
            FloatingBasketWindowController.addItemsFromExternalSource(paths)
            
            print("✅ URLSchemeHandler: Added \(paths.count) file(s) to basket")
            
        case "shelf":
            fallthrough
        default:
            // Add to notch shelf
            state.addItems(from: paths)
            
            // Show the shelf if it's not visible (use main display for URL scheme triggers)
            if !state.isExpanded {
                if let mainDisplayID = NSScreen.main?.displayID {
                    state.expandShelf(for: mainDisplayID)
                }
            }
            
            print("✅ URLSchemeHandler: Added \(paths.count) file(s) to shelf")
        }
    }
    
    /// Handles Spotify OAuth callback
    /// URL Format: pepbox://spotify-callback?code=xxx
    private static func handleSpotifyCallback(url: URL) {
        print("🎵 URLSchemeHandler: Received Spotify OAuth callback")
        
        if SpotifyAuthManager.shared.handleCallback(url: url) {
            print("✅ URLSchemeHandler: Spotify authentication successful")
        } else {
            print("⚠️ URLSchemeHandler: Spotify authentication failed")
        }
    }
    
    /// Handles extension deep links from the website
    /// URL Format: pepbox://extension/{id}
    /// Supported IDs include: ai-bg, alfred, finder, element-capture, spotify, apple-music, window-snap, voice-transcribe, video-target-size, termi-notch, notchface, snap-camera, quickshare, notification-hud, caffeine, menu-bar-manager, todo
    private static func handleExtensionAction(url: URL) {
        // Extract extension ID from path (e.g., "/ai-bg" -> "ai-bg")
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let extensionId = pathComponents.first else {
            print("⚠️ URLSchemeHandler: No extension ID in URL path")
            return
        }
        
        print("🧩 URLSchemeHandler: Opening extension '\(extensionId)'")
        
        // Map URL ID to ExtensionType
        let extensionType: ExtensionType?
        switch extensionId.lowercased() {
        case "ai-bg", "ai", "background-removal":
            extensionType = .aiBackgroundRemoval
        case "alfred", "alfred-workflow":
            extensionType = .alfred
        case "finder", "finder-services":
            extensionType = .finderServices
        case "element-capture", "element", "capture":
            extensionType = .elementCapture
        case "spotify", "spotify-integration":
            extensionType = .spotify
        case "apple-music", "applemusic", "music":
            extensionType = .appleMusic
        case "window-snap", "windowsnap", "snap":
            extensionType = .windowSnap
        case "voice-transcribe", "voicetranscribe", "transcribe":
            extensionType = .voiceTranscribe
        case "video-target-size", "ffmpeg", "video-compression":
            extensionType = .ffmpegVideoCompression
        case "termi-notch", "terminotch", "terminal", "terminal-notch":
            extensionType = .terminalNotch
        case "notchface", "snap-camera", "camera", "snapcam":
            extensionType = .camera
        case "quickshare", "quick-share":
            extensionType = .quickshare
        case "notification-hud", "notify-me", "notificationhud":
            extensionType = .notificationHUD
        case "caffeine", "high-alert", "highalert":
            extensionType = .caffeine
        case "menu-bar-manager", "menubarmanager":
            extensionType = .menuBarManager
        case "todo", "to-do", "tasks":
            extensionType = .todo
        default:
            print("⚠️ URLSchemeHandler: Unknown extension ID '\(extensionId)'")
            extensionType = nil
        }
        
        // Open Settings window and show the extension sheet
        DispatchQueue.main.async {
            // Bring app to front
            NSApp.activate(ignoringOtherApps: true)
            
            // Open Settings to Extensions tab with the specific extension sheet
            if let type = extensionType {
                SettingsWindowController.shared.showSettings(openingExtension: type)
                print("✅ URLSchemeHandler: Opened extension info sheet for '\(extensionId)'")
            } else {
                // Just open Settings to Extensions tab
                SettingsWindowController.shared.showSettings()
            }
        }
    }
}
