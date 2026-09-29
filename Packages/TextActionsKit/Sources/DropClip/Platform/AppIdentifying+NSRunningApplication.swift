// AppIdentifying+NSRunningApplication.swift
// DropClip
//
// Extends AppIdentity to initialize from NSRunningApplication.
import AppKit
import DropClipCore

extension AppIdentity {
    public init(_ app: NSRunningApplication) {
        self.init(bundleIdentifier: app.bundleIdentifier, localizedName: app.localizedName)
    }
}

