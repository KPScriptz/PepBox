// BrandColor.swift
// DropClip
//
// DropClip's own blue (`#0071e3`), close to the icon's `#0A84FF` but not the same.

import SwiftUI

public extension Color {
    /// The brand blue. In the settings sidebar it is reserved for rows DropClip ships, so a
    /// third-party extension's generated tint can never claim it — see `SettingsTint`.
    static let dropClipBrand = Color(red: 0x00 / 255, green: 0x71 / 255, blue: 0xe3 / 255)
}
