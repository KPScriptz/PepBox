//
//  ElementCaptureExtension.swift
//  PepBox
//
//  Self-contained definition for Element Capture extension
//

import SwiftUI

struct ElementCaptureExtension: ExtensionDefinition {
    static let id = "elementCapture"
    static let title = "Element Capture"
    static let subtitle = "Capture any screen element instantly"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .yellow // Matches yellow capture icon
    
    static let description = "Capture specific screen elements, annotate with arrows, shapes, text, and blur, then copy to clipboard or add to PepBox. Perfect for grabbing and marking up UI components, icons, or any visual element."
    
    static let features: [(icon: String, text: String)] = [
        ("keyboard", "Configurable keyboard shortcuts"),
        ("rectangle.dashed", "Select screen regions"),
        ("pencil.tip.crop.circle", "Annotate with arrows, shapes & text"),
        ("eye.slash", "Blur sensitive content"),
        ("doc.on.clipboard", "Copy to clipboard"),
        ("plus.circle", "Add directly to PepBox")
    ]
    
    static var screenshotURL: URL? {
        URL(string: "pepbox-media://images/element-capture-screenshot.gif")
    }
    
    static var iconURL: URL? {
        URL(string: "pepbox-media://icons/element-capture.jpg")
    }
    
    static let iconPlaceholder = "viewfinder"
    static let iconPlaceholderColor: Color = .blue
    
    static func cleanup() {
        ElementCaptureManager.shared.cleanup()
    }
}
