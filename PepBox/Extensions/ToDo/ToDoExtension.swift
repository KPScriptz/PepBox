//
//  ToDoExtension.swift
//  PepBox
//
//  Self-contained definition for Reminders extension
//

import SwiftUI

struct ToDoExtension: ExtensionDefinition {
    static let id = "todo"
    static let title = "Reminders"
    static let subtitle = "Natural language tasks"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .blue
    
    static let description = "Capture tasks in natural language, mention lists and dates, and sync with Apple Reminders. Supports multilingual input, priorities, and auto-cleanup."
    
    static let features: [(icon: String, text: String)] = [
        ("text.bubble", "Natural-language task capture"),
        ("list.bullet.rectangle.portrait", "List support with list mentions"),
        ("calendar.badge.clock", "Date mentions like tomorrow and next Friday"),
        ("globe", "Multilingual task input"),
        ("timer", "Priority levels and auto-cleanup")
    ]
    
    static let screenshotURL: URL? = URL(string: "pepbox-media://images/reminders-screenshot.gif")
    static let previewView: AnyView? = AnyView(ToDoPreviewView())
    
    static let iconURL: URL? = URL(string: "pepbox-media://icons/reminders.png")
    static let iconPlaceholder: String = "checklist"
    static let iconPlaceholderColor: Color = .blue
    
    // MARK: - Community Extension
    
    static let isCommunity = true
    static let creatorName: String? = "Valetivivek"
    static let creatorURL: URL? = URL(string: "https://github.com/valetivivek")
    
    static func cleanup() {
        ToDoManager.shared.hide()
    }
}
