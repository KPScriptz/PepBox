//
//  DropClipHostEnvironment.swift
//  DropClip, inside Droppy
//
//  DropClip runs inside Droppy's process, so the two things an app normally
//  owns outright are Droppy's here: the main bundle and the standard defaults
//  domain. Everything DropClip reads about itself goes through this file
//  instead (the port from OpenClip (PROVENANCE.md) rewrites upstream's reads to it). Here
//  in DropClipCore so both DropClip targets see it.
//

import Foundation

/// Anchors `Bundle(for:)` on the droplet's own bundle: every target links into
/// the one dynamic library the `.droplet` bundle carries.
private final class DropClipBundleToken {}

extension Bundle {
    /// The `.droplet` bundle: DropClip's identity, version, icon and resources.
    ///
    /// `Bundle.main` is Droppy.
    public nonisolated static let dropclip = Bundle(for: DropClipBundleToken.self)
}

extension UserDefaults {
    /// The defaults domain DropClip's settings live in inside Droppy.
    ///
    /// `UserDefaults.standard` is Droppy's, and names like `theme` or `isAppEnabled` would
    /// switch Droppy's own features.
    public nonisolated(unsafe) static let dropclip: UserDefaults =
        UserDefaults(suiteName: DropClipDomain.droplet) ?? .standard
}

/// The defaults domains DropClip has lived in.
public enum DropClipDomain {
    /// Text Actions' own domain inside PepBox (was Droppy's droplet domain).
    public static let droplet = "com.pivotxp.PepBox.textactions"
    /// The domain of the OpenClip droplet DropClip was until 2.1.0, which DropClip takes its
    /// settings from once (`DropClipMigration`).
    public static let openClipDroplet = "app.getdroppy.droplet.openclip"
}
