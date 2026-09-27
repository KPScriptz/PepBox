//
//  AutofadeManager.swift
//  PepBox
//
//  Manages advanced autofade settings for the media HUD
//  Supports app-specific rules, display-specific rules, and configurable delays
//

import Foundation
import Combine
import AppKit

// MARK: - Data Models

/// Autofade delay options
enum AutofadeDelay: Codable, Hashable {
    case never      // Disable autofade entirely
    case fast       // 2 seconds
    case normal     // 5 seconds (default)
    case slow       // 10 seconds
    case custom(Double)  // User-defined delay
    
    var seconds: Double? {
        switch self {
        case .never: return nil
        case .fast: return 2.0
        case .normal: return 5.0
        case .slow: return 10.0
        case .custom(let delay): return delay
        }
    }
    
    var displayName: String {
        switch self {
        case .never: return "Never"
        case .fast: return "Fast (2s)"
        case .normal: return "Normal (5s)"
        case .slow: return "Slow (10s)"
        case .custom(let delay): return "\(Int(delay))s"
        }
    }
    
    /// All standard cases for picker (excludes custom)
    static var standardCases: [AutofadeDelay] {
        [.never, .fast, .normal, .slow]
    }
}

/// An app-specific autofade rule
struct AutofadeAppRule: Codable, Identifiable, Hashable {
    let id: UUID
    let bundleIdentifier: String
    let appName: String
    let appIconPath: String?  // Path to app icon for display
    var fadeDelay: AutofadeDelay
    
    init(bundleIdentifier: String, appName: String, appIconPath: String? = nil, fadeDelay: AutofadeDelay = .normal) {
        self.id = UUID()
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.appIconPath = appIconPath
        self.fadeDelay = fadeDelay
    }
}

// MARK: - AutofadeManager

/// Centralized manager for advanced autofade settings
/// Follows the TrackedFoldersManager pattern for persistence and state management
@MainActor
final class AutofadeManager: ObservableObject {
    static let shared = AutofadeManager()
    
    // MARK: - Published State
    
    /// App-specific autofade rules
    @Published private(set) var appRules: [AutofadeAppRule] = []
    
    /// Display IDs where autofade is disabled
    @Published private(set) var disabledDisplayIDs: Set<CGDirectDisplayID> = []
    
    // MARK: - Persistence Keys
    
    private let appRulesKey = "autofadeAppRules"
    private let disabledDisplaysKey = "autofadeDisabledDisplays"
    
    // MARK: - Observers
    
    private var frontmostAppObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()
    
    /// Current frontmost app's bundle identifier
    @Published private(set) var frontmostBundleID: String?
    
    // MARK: - Initialization
    
    private init() {
        loadAppRules()
        loadDisabledDisplays()
        setupFrontmostAppMonitoring()
    }
    
    deinit {
        if let observer = frontmostAppObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
    
    // MARK: - Public API: Default Delay
    
    /// Get the default autofade delay from preferences
    var defaultDelay: Double {
        let delay = UserDefaults.standard.double(forKey: AppPreferenceKey.autofadeDefaultDelay)
        return delay > 0 ? delay : PreferenceDefault.autofadeDefaultDelay
    }
    
    // MARK: - Public API: App Rules
    
    /// Add a new app-specific autofade rule
    func addAppRule(bundleID: String, appName: String, delay: AutofadeDelay) {
        // Don't add duplicate rules
        guard !appRules.contains(where: { $0.bundleIdentifier == bundleID }) else {
            print("[Autofade] Rule already exists for \(bundleID)")
            return
        }
        
        // Get app icon path if available
        let iconPath = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path
        
        let rule = AutofadeAppRule(
            bundleIdentifier: bundleID,
            appName: appName,
            appIconPath: iconPath,
            fadeDelay: delay
        )
        
        appRules.append(rule)
        saveAppRules()
        print("[Autofade] Added rule: \(appName) = \(delay.displayName)")
    }
    
    /// Remove an app-specific autofade rule
    func removeAppRule(id: UUID) {
        appRules.removeAll { $0.id == id }
        saveAppRules()
        print("[Autofade] Removed rule")
    }
    
    /// Update the delay for an existing app rule
    func updateAppRule(id: UUID, delay: AutofadeDelay) {
        if let index = appRules.firstIndex(where: { $0.id == id }) {
            appRules[index].fadeDelay = delay
            saveAppRules()
            print("[Autofade] Updated rule to \(delay.displayName)")
        }
    }
    
    /// Get the rule for a specific bundle identifier
    func rule(for bundleID: String) -> AutofadeAppRule? {
        appRules.first { $0.bundleIdentifier == bundleID }
    }
    
    // MARK: - Public API: Display Rules
    
    /// Check if autofade is enabled for a specific display
    func isDisplayEnabled(_ displayID: CGDirectDisplayID) -> Bool {
        // Check if display-specific rules are enabled globally
        guard UserDefaults.standard.bool(forKey: AppPreferenceKey.autofadeDisplayRulesEnabled) else {
            return true  // Display rules disabled = all displays enabled
        }
        return !disabledDisplayIDs.contains(displayID)
    }
    
    /// Enable or disable autofade for a specific display
    func setDisplayEnabled(_ displayID: CGDirectDisplayID, enabled: Bool) {
        if enabled {
            disabledDisplayIDs.remove(displayID)
        } else {
            disabledDisplayIDs.insert(displayID)
        }
        saveDisabledDisplays()
        print("[Autofade] Display \(displayID) autofade: \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Public API: Effective Delay Calculation
    
    /// Calculate the effective autofade delay for the current context
    /// Returns nil if autofade should be disabled (never fade)
    /// - Parameter displayID: The display to calculate for
    /// - Returns: The delay in seconds, or nil if autofade is disabled
    func effectiveDelay(for displayID: CGDirectDisplayID) -> Double? {
        // 1. Check display-specific rules
        if !isDisplayEnabled(displayID) {
            return nil  // Autofade disabled for this display
        }
        
        // 2. Check app-specific rules (if enabled)
        if UserDefaults.standard.bool(forKey: AppPreferenceKey.autofadeAppRulesEnabled),
           let bundleID = frontmostBundleID,
           let rule = rule(for: bundleID) {
            return rule.fadeDelay.seconds  // nil if .never
        }
        
        // 3. Fall back to default delay
        return defaultDelay
    }
    
    // MARK: - Private: Persistence
    
    private func loadAppRules() {
        guard let data = UserDefaults.standard.data(forKey: appRulesKey),
              let rules = try? JSONDecoder().decode([AutofadeAppRule].self, from: data) else {
            appRules = []
            return
        }
        appRules = rules
    }
    
    private func saveAppRules() {
        guard let data = try? JSONEncoder().encode(appRules) else { return }
        UserDefaults.standard.set(data, forKey: appRulesKey)
    }
    
    private func loadDisabledDisplays() {
        guard let data = UserDefaults.standard.data(forKey: disabledDisplaysKey),
              let displayIDs = try? JSONDecoder().decode([CGDirectDisplayID].self, from: data) else {
            disabledDisplayIDs = []
            return
        }
        disabledDisplayIDs = Set(displayIDs)
    }
    
    private func saveDisabledDisplays() {
        let displayIDArray = Array(disabledDisplayIDs)
        guard let data = try? JSONEncoder().encode(displayIDArray) else { return }
        UserDefaults.standard.set(data, forKey: disabledDisplaysKey)
    }
    
    // MARK: - Private: Frontmost App Monitoring
    
    private func setupFrontmostAppMonitoring() {
        // Get initial frontmost app
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        
        // Monitor for app activation changes
        frontmostAppObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            let bundleID = app.bundleIdentifier
            Task { @MainActor [weak self] in
                self?.frontmostBundleID = bundleID
            }
        }
    }
}

// MARK: - Running App Helper

extension AutofadeManager {
    /// Get a list of currently running apps (for app picker)
    func runningApps() -> [(bundleID: String, name: String, icon: NSImage?)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }  // Only regular apps (not background)
            .compactMap { app -> (String, String, NSImage?)? in
                guard let bundleID = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                return (bundleID, name, app.icon)
            }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }
    
    /// Get all installed apps (for more comprehensive picker)
    func installedApps() -> [(bundleID: String, name: String, path: String)] {
        let appDirs = [
            "/Applications",
            "/System/Applications",
            NSHomeDirectory() + "/Applications"
        ]
        
        var apps: [(String, String, String)] = []
        let fm = FileManager.default
        
        for dir in appDirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let path = "\(dir)/\(item)"
                if let bundle = Bundle(path: path),
                   let bundleID = bundle.bundleIdentifier,
                   let name = bundle.infoDictionary?["CFBundleName"] as? String ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String {
                    apps.append((bundleID, name, path))
                }
            }
        }
        
        return apps.sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }
}
