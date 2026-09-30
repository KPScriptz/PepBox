//
//  FloatingPin.swift
//  PepBox
//
//  "Float on Screen": keeps an image or some text in a small window above
//  everything else, as a reference while you work. Drag anywhere to move,
//  drag the corner to resize, hover for the close button. Double-click to
//  toggle see-through.
//

import SwiftUI
import AppKit

enum FloatingPinContent {
    case image(NSImage)
    case text(String)
}

final class FloatingPinController {
    static let shared = FloatingPinController()
    private var panels: [NSPanel] = []

    func pin(_ content: FloatingPinContent) {
        let size: NSSize
        switch content {
        case .image(let image):
            // Fit within 420×420 keeping the aspect ratio.
            let scale = min(1, 420 / max(image.size.width, image.size.height, 1))
            size = NSSize(width: max(120, image.size.width * scale), height: max(80, image.size.height * scale))
        case .text:
            size = NSSize(width: 320, height: 200)
        }

        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.nonactivatingPanel, .resizable, .fullSizeContentView, .titled],
                            backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.minSize = NSSize(width: 100, height: 60)
        if case .image(let image) = content, image.size.width > 0 {
            panel.contentAspectRatio = image.size
        }
        panel.contentView = NSHostingView(rootView: FloatingPinView(content: content) { [weak self, weak panel] in
            guard let panel else { return }
            panel.orderOut(nil)
            self?.panels.removeAll { $0 === panel }
        } toggleSeeThrough: { [weak panel] in
            guard let panel else { return }
            panel.alphaValue = panel.alphaValue < 1 ? 1 : 0.45
        })

        // Cascade new pins near the pointer's screen centre.
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let offset = CGFloat(panels.count % 6) * 24
            panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2 + offset, y: visible.midY - size.height / 2 - offset))
        }
        panel.orderFrontRegardless()
        panels.append(panel)
    }

    func closeAll() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }
}

private struct FloatingPinView: View {
    let content: FloatingPinContent
    let onClose: () -> Void
    let toggleSeeThrough: () -> Void
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch content {
                case .image(let image):
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .text(let text):
                    ScrollView {
                        Text(text)
                            .font(.system(size: 13))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onTapGesture(count: 2, perform: toggleSeeThrough)

            if isHovering {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .padding(6)
                .help("Close (double-click the pin to make it see-through)")
            }
        }
        .onHover { isHovering = $0 }
        .ignoresSafeArea()
    }
}
