// AppearanceTabView.swift
// DropClip
//
// The Appearance preferences tab: popup preview + theme selector.
// Styled to match the modern settings cards.

import SwiftUI
import DropClipCore

@MainActor
struct AppearanceTab: View {
    var body: some View {
        // Droppy: a page of Droppy's native Settings inside Droppy.
        DropClipSettingsPageBody {
            // The preview is a fixed-size stage, so it sits above the cards
            PopupPreview()

            PopupThemeSelector()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
