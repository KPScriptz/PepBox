//
//  NotificationHUDExtension.swift
//  PepBox
//
//  Self-contained definition for Notification HUD extension
//

import SwiftUI

struct NotificationHUDExtension: ExtensionDefinition {
    static let id = "notificationHUD"
    static let title = "Notify me!"
    static let subtitle = "Show notifications in your notch"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .red // Matches red notification bell icon
    
    static let description = "Capture macOS notifications and display them directly in the notch, like iPhone's Dynamic Island. Click to open the source app, swipe up to dismiss."
    
    static let features: [(icon: String, text: String)] = [
        ("bell.badge.fill", "Display notifications in the notch"),
        ("app.badge.fill", "Show app icon and preview text"),
        ("hand.tap.fill", "Click to open, swipe to dismiss"),
        ("slider.horizontal.3", "Per-app notification filtering")
    ]
    
    static let screenshotURL: URL? = URL(string: "https://getdroppy.app/assets/images/notification-hud-screenshot.png")
    static let previewView: AnyView? = nil
    
    static let iconURL: URL? = URL(string: "https://getdroppy.app/assets/icons/notification-hud.png")
    static let iconPlaceholder: String = "bell.badge.fill"
    static let iconPlaceholderColor: Color = .orange
    
    static func cleanup() {
        NotificationHUDManager.shared.stopMonitoring()
    }
    
    // MARK: - Community Extension
    
    static let isCommunity = true
    static let creatorName: String? = "Valetivivek"
    static let creatorURL: URL? = URL(string: "https://github.com/valetivivek")
}
