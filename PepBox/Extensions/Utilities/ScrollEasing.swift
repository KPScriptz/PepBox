//
//  ScrollEasing.swift
//  PepBox
//
//  Smooth Scroll's per-frame step. No app dependencies, so scripts/logic-tests
//  can check that every glide ends and delivers its full distance.
//

import Foundation

enum ScrollEasing {
    static let pixelsPerLine: Double = 42

    /// Pixels to scroll this frame for the distance still pending: a fraction of it,
    /// the rest outright when under a pixel, and never 0 while at least half a pixel
    /// remains (otherwise the glide would never end).
    static func nextStep(remaining: Double, easing: Double) -> Int32 {
        let delta = abs(remaining) < 1 ? remaining : remaining * easing
        let rounded = Int32(delta.rounded())
        if rounded == 0 && abs(remaining) >= 0.5 { return remaining > 0 ? 1 : -1 }
        return rounded
    }
}
