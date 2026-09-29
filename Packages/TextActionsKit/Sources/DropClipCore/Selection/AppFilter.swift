// AppFilter.swift
// DropClip
//
// Maintains exclusion pattern lists to prevent DropClip from running on unsupported system or game applications.
import Foundation

public struct AppFilter: Sendable {
    public static let excludedBundleIDPatterns: [String] = [
        "com.adobe.*",
        "com.adobe.aerendercore",
        "com.amazon.Kindle",
        "com.apple.CharacterPaletteIM",
        "com.apple.dock",
        "com.apple.iphonesimulator",
        "com.apple.systemuiserver",
        "com.blizzard.*",
        "com.codeweavers.*",
        "com.collectorz.*",
        "com.dropclip.*",      // Never trigger on ourselves
        "com.oracle.SQLDeveloper",
        "com.parallels.*",
        "com.pilotmoon.popclip",
        "com.pixelmatorteam.*",
        "com.revolversoftware.office",
        "com.screencastomatic.app",
        "com.unity3d.*",
        "com.vmware.*",
        "net.java.openjdk.cmd",
        "org.keepassx.keepassx",
        "com.edovia.screens.*"
    ]
    
    public static func isExcluded(bundleID: String) -> Bool {
        // Droppy: "never trigger on ourselves" means the app DropClip's windows are in, which
        // inside Droppy is Droppy (its Settings, where DropClip's own pages are, included).
        if let host = Bundle.main.bundleIdentifier, bundleID == host { return true }
        for pattern in excludedBundleIDPatterns {
            if pattern.hasSuffix(".*") {
                let prefix = String(pattern.dropLast(2))
                // Exact match OR subdomain match — prevents "com.foo" matching "com.foobar"
                if bundleID == prefix || bundleID.hasPrefix(prefix + ".") { return true }
            } else {
                if bundleID == pattern { return true }
            }
        }
        return false
    }
}
