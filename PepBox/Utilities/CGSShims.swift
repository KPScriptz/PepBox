// MARK: - Private SkyLight API for Fullscreen Space Detection
// These are private Core Graphics Server functions used for fullscreen detection.
// Previously provided by MenuBarManager/Bridging/Shims.swift but moved here
// since it's used by NotchWindowController for all-display fullscreen detection.

import Foundation

/// Connection ID for the current session
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> UInt32

/// Get managed display spaces info (includes fullscreen state via TileLayoutManager)
@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ cid: UInt32) -> CFArray?
