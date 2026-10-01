//
//  OCRResultView.swift
//  PepBox
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI

struct OCRResultView: View {
    let text: String
    let onClose: () -> Void
    
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @State private var isCopyHovering = false
    @State private var isCloseHovering = false
    @State private var showCopiedFeedback = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Extracted Text")
                        .font(.headline)
                    Text("Text recognized from image")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(PepBoxSpacing.xl)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Content
            ScrollView {
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(PepBoxSpacing.xl)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 300)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Action buttons
            HStack(spacing: 10) {
                Button {
                    onClose()
                } label: {
                    Text("Close")
                }
                .buttonStyle(PepBoxPillButtonStyle(size: .small))
                
                Spacer()
                
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(text, forType: .string)
                    
                    withAnimation(PepBoxAnimation.hover) {
                        showCopiedFeedback = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        onClose()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                        Text(showCopiedFeedback ? "Copied!" : "Copy to Clipboard")
                    }
                }
                .buttonStyle(PepBoxAccentButtonStyle(color: showCopiedFeedback ? .green : .blue, size: .small))
            }
            .padding(PepBoxSpacing.lg)
        }
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .pepboxSurface(transparent: useTransparentBackground)
    }
}
