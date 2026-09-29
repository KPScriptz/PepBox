// PermissionManager.swift
// DropClip
//
// Checks and prompts for required macOS Accessibility permissions necessary for text retrieval and event monitoring.
import Combine
import AppKit
import ApplicationServices
import DropClipCore

/// Centralized manager for macOS system accessibility permissions.
/// Uses a continuous async polling loop (not Timer) to reliably detect
/// AXIsProcessTrusted changes on the main actor.
@MainActor
public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()

    @Published public private(set) var isAccessibilityGranted: Bool = false

    private var pollingTask: Task<Void, Never>?

    private init() {
        self.isAccessibilityGranted = Self.queryAX()
    }

    // MARK: - Public API

    /// Start continuously polling AX status every 0.5 s.
    public func startMonitoring() {
        guard pollingTask == nil else { return }
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.checkStatus()
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 s
            }
        }
    }

    /// Stop polling.
    public func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Single manual check — useful for the "Re-check" button.
    public func checkStatus() {
        let current = Self.queryAX()
        if isAccessibilityGranted != current {
            isAccessibilityGranted = current
            NotificationCenter.default.post(name: .dropClipAccessibilityChanged, object: current)
        }
    }

    /// Open System Settings → Accessibility and prompt macOS TCC to evaluate the running binary.
    /// - Parameter proactivelyResetStaleTCC: When true (default), silently clears any stale or disabled
    ///   TCC cache entry for DropClip via `tccutil reset` before opening settings, preventing the macOS
    ///   "stuck disabled / toggle not working" bug on updates and reinstalls.
    public func requestAccessibilityPermission(proactivelyResetStaleTCC: Bool = true) {
        // Start monitoring immediately so UI reflects the current grant without waiting for tccutil (up to 30s).
        startMonitoring()
        // Droppy: inside Droppy the permission is Droppy's own, granted to Droppy; resetting the
        // DropClip app's entry would do nothing for it, and Droppy's must never be reset from here.
        if proactivelyResetStaleTCC, !DropClipHost.isHosted {
            Task { @MainActor in
                do {
                    _ = try await ShellProcessRunner.run(ShellProcessRunner.Invocation(
                        executableURL: URL(fileURLWithPath: "/usr/bin/tccutil"),
                        arguments: ["reset", "Accessibility", "com.dropclip.Text Actions"],
                        environment: [:]
                    ))
                } catch {
                    Log.permissions.error("Failed to run proactive tccutil reset: \(error.localizedDescription)")
                }
                promptAndOpenAccessibilitySettings()
            }
        } else {
            promptAndOpenAccessibilitySettings()
        }
    }

    private func promptAndOpenAccessibilitySettings() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Reset TCC permission database entry for DropClip if macOS TCC is caching a stale signature.
    public func resetTCCAndRelaunch() {
        // Droppy: no reset and no relaunch inside Droppy (both would be Droppy's): open the
        // Accessibility pane, where the switch that counts is Droppy's.
        if DropClipHost.isHosted {
            promptAndOpenAccessibilitySettings()
            return
        }
        // Run tccutil asynchronously — never `waitUntilExit` on the main actor. The app relaunches
        // regardless so TCC re-evaluates the running binary.
        Task {
            do {
                _ = try await ShellProcessRunner.run(ShellProcessRunner.Invocation(
                    executableURL: URL(fileURLWithPath: "/usr/bin/tccutil"),
                    arguments: ["reset", "Accessibility", "com.dropclip.Text Actions"],
                    environment: [:]
                ))
            } catch {
                Log.permissions.error("Failed to run tccutil reset for Accessibility permission: \(error.localizedDescription)")
            }
            relaunchApp()
        }
    }

    /// Relaunch the app so macOS TCC registers the new permission for the running process.
    public func relaunchApp() {
        // Droppy: relaunching would quit Droppy, and the droplet's bundle is not an app to open.
        // Droppy's own permission is live-checked, so there is nothing to relaunch for.
        if DropClipHost.isHosted {
            checkStatus()
            return
        }
        let url = Bundle.dropclip.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    // MARK: - Internal

    /// Direct TCC query — bypasses any in-process caching.
    private static func queryAX() -> Bool {
        AXIsProcessTrustedWithOptions(nil)
    }
}
