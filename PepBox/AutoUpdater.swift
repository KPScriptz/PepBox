//
//  AutoUpdater.swift
//  PepBox
//
//  Created by Jordy Spruit on 02/01/2026.
//

import Foundation
import AppKit
import Security
import SwiftUI

/// Handles downloading and installing app updates
class AutoUpdater {
    static let shared = AutoUpdater()
    
    private init() {}
    
    /// Downloads and installs the update from the given URL
    func installUpdate(from url: URL) {
        Task {
            // 1. Download DMG
            guard let dmgURL = await downloadDMG(from: url) else {
                return
            }

            // 2. Only install an app signed by the same developer as this one, so a
            //    tampered or wrong download can never replace PepBox.
            if let problem = UpdateVerifier.problem(withDMGAt: dmgURL) {
                print("AutoUpdater: Refusing update: \(problem)")
                try? FileManager.default.removeItem(at: dmgURL)
                await MainActor.run { Self.progress(nil, text: "Update not installed") }
                await PepBoxAlertController.shared.showError(
                    title: "Update Not Installed",
                    message: "The downloaded update didn't pass PepBox's signature check, so nothing was changed. \(problem)"
                )
                return
            }
            await MainActor.run { Self.progress(1, text: "Installing update…") }

            // 3. Install and Restart using helper app
            do {
                try launchUpdaterHelper(dmgPath: dmgURL.path)
            } catch {
                print("AutoUpdater: Installation failed: \(error)")
                await PepBoxAlertController.shared.showError(
                    title: "Update Failed",
                    message: error.localizedDescription
                )
            }
        }
    }
    
    private func downloadDMG(from url: URL) async -> URL? {
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("PepBoxUpdate.dmg")
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            await MainActor.run { Self.progress(0, text: "Downloading update…") }
            let downloaded = try await UpdateDownload.run(url) { fraction in
                Task { @MainActor in Self.progress(fraction, text: "Downloading update…") }
            }
            try FileManager.default.moveItem(at: downloaded, to: destinationURL)
            return destinationURL
        } catch {
            print("AutoUpdater: Download failed: \(error)")
            await MainActor.run { Self.progress(nil, text: "Update download failed") }
            await PepBoxAlertController.shared.showError(
                title: "Update Failed",
                message: "Could not download the update. Please try again later."
            )
            return nil
        }
    }
    
    /// Download/install progress beside the notch.
    @MainActor
    private static func progress(_ fraction: Double?, text: String) {
        FlashActivity.shared.show(LiveActivity(id: "pepbox-update", icon: "arrow.down.circle.fill", tint: .blue,
                                               text: text, progress: fraction), for: fraction == nil ? 4 : 120)
    }

    private func launchUpdaterHelper(dmgPath: String) throws {
        let appPath = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        
        // Look for the helper in the app bundle
        let helperInBundle = Bundle.main.bundlePath + "/Contents/Helpers/PepBoxUpdater"
        
        // Fallback to temp directory (for development)
        let helperInTemp = FileManager.default.temporaryDirectory.appendingPathComponent("PepBoxUpdater").path
        
        // Determine which helper to use
        let helperPath: String
        if FileManager.default.fileExists(atPath: helperInBundle) {
            helperPath = helperInBundle
        } else if FileManager.default.fileExists(atPath: helperInTemp) {
            helperPath = helperInTemp
        } else {
            // Fallback: Copy helper from source location to temp
            let sourceHelper = (Bundle.main.bundlePath as NSString)
                .deletingLastPathComponent
                .appending("/PepBoxUpdater/PepBoxUpdater")
            
            if FileManager.default.fileExists(atPath: sourceHelper) {
                try? FileManager.default.copyItem(atPath: sourceHelper, toPath: helperInTemp)
                helperPath = helperInTemp
            } else {
                // Ultimate fallback: Use Terminal script
                try fallbackToTerminalScript(dmgPath: dmgPath, appPath: appPath, pid: pid)
                return
            }
        }
        
        // Launch the helper
        let process = Process()
        process.executableURL = URL(fileURLWithPath: helperPath)
        process.arguments = [dmgPath, appPath, String(pid)]
        
        try process.run()
        
        // Terminate current app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }
    
    /// Fallback to Terminal script if helper is not available
    private func fallbackToTerminalScript(dmgPath: String, appPath: String, pid: Int32) throws {
        let scriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("update_pepbox.command").path
        let appName = "PepBox.app"
        
        let script = """
        #!/bin/bash
        
        # Colors
        BLUE='\\033[0;34m'
        PURPLE='\\033[0;35m'
        CYAN='\\033[0;36m'
        GREEN='\\033[0;32m'
        BOLD='\\033[1m'
        NC='\\033[0m'
        
        clear
        echo -e "${BLUE}${BOLD}"
        echo "    ____  ____  ____  ____  ______  __"
        echo "   / __ \\/ __ \\/ __ \\/ __ \\/ __ \\ \\/ /"
        echo "  / / / / /_/ / / / / /_/ / /_/ /\\  / "
        echo " / /_/ / _, _/ /_/ / ____/ ____/ / /  "
        echo "/_____/_/ |_|\\____/_/   /_/     /_/   "
        echo -e "${NC}"
        echo -e "${PURPLE}${BOLD}    >>> UPDATING PEPBOX <<<${NC}"
        echo ""
        
        APP_PATH="\(appPath)"
        DMG_PATH="\(dmgPath)"
        APP_NAME="\(appName)"
        OLD_PID=\(pid)
        
        # Kill and wait
        echo -e "${CYAN}⏳ Closing PepBox...${NC}"
        kill -9 $OLD_PID 2>/dev/null || true
        sleep 2
        
        # Mount
        echo -e "${CYAN}📦 Mounting update image...${NC}"
        hdiutil attach "$DMG_PATH" -nobrowse -mountpoint /Volumes/PepBoxUpdate > /dev/null 2>&1
        
        # Remove old
        echo -e "${CYAN}🗑️  Removing old version...${NC}"
        rm -rf "$APP_PATH" 2>/dev/null || osascript -e "do shell script \\"rm -rf '$APP_PATH'\\" with administrator privileges" 2>/dev/null
        
        # Install
        echo -e "${CYAN}🚀 Installing new PepBox...${NC}"
        cp -R "/Volumes/PepBoxUpdate/$APP_NAME" "$APP_PATH"
        xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null || true
        
        # Cleanup
        echo -e "${CYAN}🧹 Cleaning up...${NC}"
        hdiutil detach /Volumes/PepBoxUpdate > /dev/null 2>&1 || true
        rm -f "$DMG_PATH" 2>/dev/null || true
        
        echo ""
        echo -e "${GREEN}${BOLD}✅ UPDATE COMPLETE!${NC}"
        sleep 1
        open -n "$APP_PATH"
        (sleep 1 && rm -f "$0") &
        exit 0
        """
        
        try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        
        var attributes = [FileAttributeKey : Any]()
        attributes[.posixPermissions] = 0o755
        try FileManager.default.setAttributes(attributes, ofItemAtPath: scriptPath)
        
        NSWorkspace.shared.open(URL(fileURLWithPath: scriptPath))
        NSApplication.shared.terminate(nil)
    }
}

/// Streams the DMG to disk and reports progress (0...1).
private final class UpdateDownload: NSObject, URLSessionDownloadDelegate {
    private let onProgress: (Double) -> Void
    private var continuation: CheckedContinuation<URL, Error>?

    private init(onProgress: @escaping (Double) -> Void) { self.onProgress = onProgress }

    static func run(_ url: URL, onProgress: @escaping (Double) -> Void) async throws -> URL {
        let delegate = UpdateDownload(onProgress: onProgress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        return try await withCheckedThrowingContinuation { continuation in
            delegate.continuation = continuation
            session.downloadTask(with: url).resume()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The temp file is deleted when this returns, so move it first.
        let kept = FileManager.default.temporaryDirectory.appendingPathComponent("PepBoxUpdate-\(UUID().uuidString).dmg")
        do {
            if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            try FileManager.default.moveItem(at: location, to: kept)
            continuation?.resume(returning: kept)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { continuation?.resume(throwing: error); continuation = nil }
    }
}

/// Checks the app inside an update DMG before it's installed.
enum UpdateVerifier {
    /// Nil when the DMG holds a validly signed PepBox.app from this app's own team; otherwise why not.
    static func problem(withDMGAt dmg: URL) -> String? {
        guard let team = teamID(ofCodeAt: Bundle.main.bundleURL) else {
            return "This copy of PepBox isn't signed, so it can't check updates. Download the new version from the website."
        }
        let mountPoint = FileManager.default.temporaryDirectory.appendingPathComponent("PepBoxVerify-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        defer {
            run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force", "-quiet"])
            try? FileManager.default.removeItem(at: mountPoint)
        }
        guard run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen", "-quiet", "-mountpoint", mountPoint.path]) else {
            return "The download isn't a readable disk image."
        }
        let app = mountPoint.appendingPathComponent("PepBox.app")
        guard FileManager.default.fileExists(atPath: app.path) else { return "There's no PepBox.app in the download." }

        var code: SecStaticCode?
        var requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString("anchor apple generic and certificate leaf[subject.OU] = \"\(team)\"" as CFString, [], &requirement) == errSecSuccess
        else { return "Its signature couldn't be read." }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        let status = SecStaticCodeCheckValidity(code, flags, requirement)
        return status == errSecSuccess ? nil : "It isn't signed by the PepBox developer (code \(status))."
    }

    static func teamID(ofCodeAt url: URL) -> String? {
        var code: SecStaticCode?
        var info: CFDictionary?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return nil }
        return dict[kSecCodeInfoTeamIdentifier as String] as? String
    }

    @discardableResult
    private static func run(_ tool: String, _ args: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
