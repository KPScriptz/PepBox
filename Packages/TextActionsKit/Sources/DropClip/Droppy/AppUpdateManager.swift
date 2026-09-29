//
//  AppUpdateManager.swift
//  DropClip, inside Droppy
//
//  Upstream's Sparkle updater, inert: inside Droppy, DropClip is a droplet,
//  and the Droplet Store updates it with the rest of Droppy's droplets.
//

import Combine
import Foundation
import DropClipCore

/// Droppy: stands in for `Platform/AppUpdateManager.swift` (Sparkle), which the port from OpenClip (PROVENANCE.md)
/// leaves out. The surface About reads stays, and nothing ever finds an update here: the Droplet
/// Store installs every new DropClip, and About says so (`DropClipStoreUpdatesNote`).
@MainActor
public final class AppUpdateManager: NSObject, ObservableObject {
    public static let shared = AppUpdateManager()

    @Published public private(set) var availableUpdateVersion: String?
    @Published public private(set) var availableUpdateReleaseNotes: String?
    @Published public private(set) var isUpdateStagedForQuitInstall = false
    @Published public private(set) var canCheckForUpdates = false
    @Published public var automaticallyChecksForUpdates = false
    @Published public var automaticallyDownloadsUpdates = false
    @Published public var notifyOnUpdate = false
    @Published public var updateChannel: UpdateChannel = .stable

    private override init() {
        super.init()
    }

    public var lastUpdateCheckDate: Date? { nil }

    /// PepBox updates Text Actions together with the app, so there is nothing to check here.
    public func checkForUpdates() {}

    public func installUpdateNow() {}
    public func installUpdateOnQuit() {}
}
