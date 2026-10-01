import AppKit
//
//  PepBoxHost.swift
//  Text Actions (DropClip in PepBox)
//
//  PepBox's replacement for DropClip's Droppy host layer (which needs DroppyKit, a
//  proprietary SDK). Reporting "not inside Droppy" makes DropClip take its standalone
//  (upstream OpenClip) paths: its own settings window and its own popup glass.
//

import SwiftUI

enum DropClipHost {
    /// Always false in PepBox: DropClip runs standalone-style.
    static var isInsideDroppy: Bool { false }

    /// Only used for Droppy's surfaces; PepBox's popups follow the system appearance.
    static var surfaceScheme: ColorScheme { .dark }

    /// Settings pages keep their search at the top of the page.
    static var pageSearchInToolbar: Bool { false }

    /// DropClip's own menu bar icon and login item: PepBox has its own.
    static var showsOwnAppControls: Bool { false }

    /// Running inside a host app: the Dock icon / activation policy, relaunching, the login
    /// item and the Accessibility (TCC) entry all belong to PepBox, never to Text Actions.
    static var isHosted: Bool { true }
}

/// Only drawn inside Droppy; kept so shared code compiles, with a plain material fallback.
struct DropClipPopupSurface: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.regularMaterial)
    }
}

/// Links shown on the About page.
enum DropClipLinks {
    /// Credit: DropClip's source, which Text Actions is.
    static let source = "https://gitlab.com/droppyformac1/droplets/-/tree/main/droplets/dropclip"

    /// Every licence Text Actions carries, bundled in the package's resources.
    @MainActor
    static func openAcknowledgements() {
        if let url = Bundle.module.url(forResource: "Acknowledgements", withExtension: "txt", subdirectory: "Assets/Legal") {
            NSWorkspace.shared.open(url)
        }
    }
}
