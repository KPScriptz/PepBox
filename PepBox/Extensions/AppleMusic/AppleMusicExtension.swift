//
//  AppleMusicExtension.swift
//  PepBox
//
//  Self-contained definition for Apple Music Integration extension
//

import SwiftUI

struct AppleMusicExtension: ExtensionDefinition {
    static let id = "appleMusic"
    static let title = "Apple Music Integration"
    static let subtitle = "Native controls for Apple Music"
    static let category: ExtensionGroup = .media
    static let categoryColor = Color(red: 0.98, green: 0.34, blue: 0.40) // Apple Music pink
    
    static let description = "Control Apple Music directly from your notch with shuffle, repeat, and love controls. See album art, track info, and playback controls without switching apps."
    
    static let features: [(icon: String, text: String)] = [
        ("music.note", "Now playing info in notch"),
        ("play.circle.fill", "Playback controls"),
        ("shuffle", "Shuffle & repeat controls"),
        ("heart.fill", "Love songs instantly")
    ]
    
    static var screenshotURL: URL? {
        URL(string: "pepbox-media://images/applemusic-screenshot.jpg")
    }
    
    static var iconURL: URL? {
        URL(string: "pepbox-media://icons/apple-music.png")
    }
    
    static let iconPlaceholder = "music.note"
    static let iconPlaceholderColor = Color(red: 0.98, green: 0.34, blue: 0.40)
    
    static func cleanup() {
        AppleMusicController.shared.cleanup()
    }
}
