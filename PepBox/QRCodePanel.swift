//
//  QRCodePanel.swift
//  PepBox
//
//  Shows text or a link as a QR code in a small floating panel, so it can be
//  scanned with a phone. Click outside or press Esc to close.
//

import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum QRCodeGenerator {
    /// QR codes top out around 2.9 KB of text; longer input returns nil.
    static let maxLength = 2000

    static func image(for text: String, size: CGFloat = 480) -> NSImage? {
        guard !text.isEmpty, text.utf8.count <= maxLength else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = floor(size / output.extent.width)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: scaled.extent.width / 2, height: scaled.extent.height / 2))
    }
}

final class QRCodePanelController {
    static let shared = QRCodePanelController()

    private var panel: NSPanel?
    private var monitors: [Any] = []

    func show(_ text: String) {
        close()
        guard let image = QRCodeGenerator.image(for: text) else {
            NSSound.beep()
            return
        }
        let view = QRCodePanelView(image: image, text: text) { [weak self] in self?.close() }
        let hosting = NSHostingView(rootView: view)
        hosting.frame.size = hosting.fittingSize

        let panel = NSPanel(contentRect: hosting.frame, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = hosting
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: visible.midX - hosting.frame.width / 2, y: visible.midY - hosting.frame.height / 2))
        }
        panel.orderFrontRegardless()
        self.panel = panel

        if let clicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in self?.close() }) {
            monitors.append(clicks)
        }
        // Clicks in PepBox's own windows (like the clipboard list) are local events.
        if let localClicks = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] event in
            if event.window !== self?.panel { self?.close() }
            return event
        }) {
            monitors.append(localClicks)
        }
        if let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            if event.keyCode == 53 { self?.close(); return nil }
            return event
        }) {
            monitors.append(keys)
        }
    }

    func close() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct QRCodePanelView: View {
    let image: NSImage
    let text: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .frame(width: 240, height: 240)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
            Text("Scan with your phone's camera")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: 264)
            HStack(spacing: 8) {
                Button("Copy Image") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([image])
                    onClose()
                }
                Button("Done", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.small)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.black.opacity(0.92)))
        .environment(\.colorScheme, .dark)
    }
}
