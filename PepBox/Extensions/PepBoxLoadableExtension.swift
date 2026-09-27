//
//  PepBoxLoadableExtension.swift
//  PepBox
//
//  Protocol for dynamically-loaded extension bundles
//  Extensions are downloaded on-demand and loaded at runtime
//

import SwiftUI
import Foundation

// MARK: - Loadable Extension Protocol

/// Protocol for extensions that can be dynamically loaded from bundles
/// Extensions must inherit from NSObject for Objective-C runtime discovery
@objc public protocol PepBoxLoadableExtension: NSObjectProtocol {
    
    // MARK: - Identity
    
    /// Unique identifier (matches ExtensionType rawValue)
    @objc static var identifier: String { get }
    
    /// Display name shown in Extension Store
    @objc static var displayName: String { get }
    
    /// Version string (semver format: "1.2.3")
    @objc static var version: String { get }
    
    // MARK: - Lifecycle
    
    /// Called when extension is loaded/activated
    @objc func activate()
    
    /// Called when extension is deactivated/unloaded
    @objc func deactivate()
    
    // MARK: - Optional UI
    
    /// Settings view for this extension (optional)
    @objc optional func settingsView() -> NSView?
    
    /// Info view shown in extension details (optional)
    @objc optional func infoView() -> NSView?
}

// MARK: - Extension Manifest

/// Manifest for an extension in the remote store
/// Fetched from Supabase to know what's available for download
struct ExtensionManifest: Codable, Identifiable {
    let id: String
    let name: String
    let version: String
    let bundleSize: Int64           // Size in bytes
    let downloadURL: URL            // GitHub Releases URL
    let checksum: String            // SHA256 hash
    let minAppVersion: String?      // Minimum PepBox version required
    let category: String
    let description: String
    let iconURL: URL?
    
    /// Whether this version is compatible with current app
    var isCompatible: Bool {
        guard let minVersion = minAppVersion else { return true }
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        return current.compare(minVersion, options: .numeric) != .orderedAscending
    }
    
    /// Human-readable size (e.g., "312 MB")
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: bundleSize, countStyle: .file)
    }
}

// MARK: - Extension State

/// State of an extension in the local system
enum ExtensionState: Equatable {
    case notInstalled
    case downloading(progress: Double)
    case installed(version: String)
    case updateAvailable(currentVersion: String, newVersion: String)
    case loadError(String)
}

// MARK: - Extension Bundle Info

/// Metadata extracted from a loaded extension bundle
struct LoadedExtensionInfo {
    let identifier: String
    let displayName: String
    let version: String
    let bundle: Bundle
    let instance: PepBoxLoadableExtension
}
