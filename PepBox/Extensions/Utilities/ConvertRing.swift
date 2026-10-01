//
//  ConvertRing.swift
//  PepBox
//
//  Hold Shift while dragging files and a ring of formats opens at the pointer;
//  drop on one and the files are converted next to the originals. Option-Shift
//  shows tools instead (compress, strip metadata, merge, zip…). Drop in the
//  middle, or let go anywhere else, to cancel.
//

import AppKit
import SwiftUI

@Observable
final class ConvertRingModel {
    var targets: [RingTarget] = []
    var highlighted: Int?
    var tools = false
    var count = 0
}

final class ConvertRingController {
    static let shared = ConvertRingController()

    static let outerRadius: CGFloat = 132
    static let innerRadius: CGFloat = 46
    private static let size: CGFloat = 300

    private(set) var isEnabled = false
    private var panel: NSPanel?
    private let model = ConvertRingModel()
    private var urls: [URL] = []
    /// Set once the ring was dismissed for this drag, so it doesn't reopen while Shift is still held.
    private var dismissedThisDrag = false

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled { close() }
    }

    // MARK: Driven by DragMonitor

    /// Called on every drag-monitor tick while a drag is in progress.
    func dragMoved(to mouse: CGPoint) {
        guard isEnabled, !dismissedThisDrag else { return }
        // The window server's live key state: NSEvent.modifierFlags can lag behind
        // while another app owns the drag, which opened the ring late.
        let flags = CGEventSource.flagsState(.combinedSessionState)
        guard flags.contains(.maskShift) else { return }
        let tools = flags.contains(.maskAlternate)
        if panel != nil {
            // Switching between Shift and Option-Shift while the ring is open swaps its contents.
            if tools != model.tools { load(tools: tools) }
            return
        }
        urls = Self.draggedFileURLs()
        guard !urls.isEmpty else { return }
        load(tools: tools)
        guard !model.targets.isEmpty else { return }
        open(at: mouse)
    }

    func dragEnded() {
        // A drop on the ring closes it itself; this covers letting go anywhere else.
        dismissedThisDrag = false
        close()
    }

    private func load(tools: Bool) {
        let extensions = urls.map(\.pathExtension)
        model.tools = tools
        model.count = urls.count
        model.highlighted = nil
        model.targets = tools
            ? ConvertRing.toolTargets(for: extensions)
            : ConvertRing.formatTargets(for: extensions, ffmpeg: ConvertRingEngine.ffmpegPath != nil)
    }

    private static func draggedFileURLs() -> [URL] {
        let pasteboard = NSPasteboard(name: .drag)
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        // Skip URLs whose file is gone (a stale or synthetic drag).
        return urls.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    // MARK: Panel

    private func open(at mouse: CGPoint) {
        let size = Self.size
        var frame = NSRect(x: mouse.x - size / 2, y: mouse.y - size / 2, width: size, height: size)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
            let visible = screen.visibleFrame
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - size)
            frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - size)
        }

        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        let ring = NSHostingView(rootView: ConvertRingView(model: model))
        ring.frame = container.bounds
        ring.autoresizingMask = [.width, .height]
        container.addSubview(ring)
        // The drop target sits on top of the drawing so it gets every drag event.
        let drop = ConvertRingDropView(frame: container.bounds)
        drop.autoresizingMask = [.width, .height]
        drop.onHover = { [weak self] index in
            guard let self, self.model.highlighted != index else { return }
            withAnimation(.easeOut(duration: 0.1)) { self.model.highlighted = index }
            if index != nil { HapticFeedback.tap() }
        }
        drop.onDrop = { [weak self] index, dropped in self?.perform(index: index, dropped: dropped) ?? false }
        drop.segmentCount = { [weak self] in self?.model.targets.count ?? 0 }
        container.addSubview(drop)

        panel.contentView = container
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
        model.highlighted = nil
    }

    private func perform(index: Int?, dropped: [URL]) -> Bool {
        guard let index, model.targets.indices.contains(index) else {
            // Dropped in the hole: cancel, and don't reopen until the next drag.
            dismissedThisDrag = true
            close()
            return false
        }
        let target = model.targets[index]
        let files = dropped.isEmpty ? urls : dropped
        dismissedThisDrag = true
        close()
        convert(files, with: target)
        return true
    }

    private func convert(_ files: [URL], with target: RingTarget) {
        let id = "convert-\(UUID())"
        let label = files.count == 1 ? "Converting \(files[0].lastPathComponent)" : "Converting \(files.count) files"
        FlashActivity.shared.show(LiveActivity(id: id, icon: "arrow.triangle.2.circlepath", tint: .orange,
                                               text: target.action == .readQR ? "Reading QR…" : label, progress: nil), for: 600)
        Task {
            let result = await ConvertRingEngine.run(target, on: files)
            await MainActor.run { Self.report(result, target: target) }
        }
    }

    private static func report(_ result: ConvertRingEngine.Result, target: RingTarget) {
        let text: String
        let icon: String
        let tint: Color
        if let message = result.message {
            text = "QR copied: \(message.prefix(40))"
            icon = "qrcode"; tint = .green
        } else if result.outputs.isEmpty {
            switch target.action {
            case .readQR: text = "No QR code found"
            case .compress: text = "Already as small as it gets"
            default: text = "Couldn't convert to \(target.title)"
            }
            icon = "exclamationmark.triangle.fill"; tint = .red
        } else {
            let made = result.outputs.count == 1 ? result.outputs[0].lastPathComponent : "\(result.outputs.count) files"
            text = result.failures > 0 ? "\(made) saved, \(result.failures) failed" : "\(made) saved"
            icon = "checkmark.circle.fill"; tint = result.failures > 0 ? .orange : .green
            HapticFeedback.copy()
        }
        FlashActivity.shared.show(LiveActivity(id: "convert-done-\(UUID())", icon: icon, tint: tint, text: text, progress: nil), for: 4)
    }
}

/// Transparent view over the ring that takes the drop and tracks which segment the pointer is over.
final class ConvertRingDropView: NSView {
    var onHover: ((Int?) -> Void)?
    var onDrop: ((Int?, [URL]) -> Bool)?
    var segmentCount: () -> Int = { 0 }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func segment(for info: NSDraggingInfo) -> Int? {
        let point = convert(info.draggingLocation, from: nil)
        let relative = CGPoint(x: point.x - bounds.midX, y: point.y - bounds.midY)
        return ConvertRing.segment(at: relative, count: segmentCount(),
                                   innerRadius: ConvertRingController.innerRadius, outerRadius: ConvertRingController.outerRadius)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { draggingUpdated(sender) }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let index = segment(for: sender)
        onHover?(index)
        return index == nil ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { onHover?(nil) }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return onDrop?(segment(for: sender), urls) ?? false
    }
}

struct ConvertRingView: View {
    let model: ConvertRingModel
    @State private var appeared = false

    private let outer = ConvertRingController.outerRadius
    private let inner = ConvertRingController.innerRadius

    var body: some View {
        let count = model.targets.count
        ZStack {
            // Dense enough that text behind the ring doesn't compete with the labels.
            Circle()
                .fill(.regularMaterial)
                .overlay(Circle().fill(Color.black.opacity(0.35)))
                .frame(width: outer * 2, height: outer * 2)
                .shadow(color: .black.opacity(0.3), radius: 18, y: 6)

            ForEach(Array(model.targets.enumerated()), id: \.element.id) { index, target in
                let on = model.highlighted == index
                RingSegmentShape(index: index, count: count, inner: inner + 3, outer: outer - 3)
                    .fill(on ? Color.accentColor : Color.white.opacity(0.06), style: FillStyle(eoFill: true))
                RingSegmentShape(index: index, count: count, inner: inner + 3, outer: outer - 3)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                segmentLabel(target, highlighted: on)
                    .offset(labelOffset(index: index, count: count))
            }

            VStack(spacing: 1) {
                Image(systemName: model.tools ? "wrench.and.screwdriver" : "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                Text(model.count == 1 ? "1 file" : "\(model.count) files")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: inner * 2, height: inner * 2)
            .background(Circle().fill(Color.black.opacity(0.25)))
        }
        .frame(width: 300, height: 300)
        .scaleEffect(appeared ? 1 : 0.7)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) { appeared = true } }
        .environment(\.colorScheme, .dark)
    }

    private func segmentLabel(_ target: RingTarget, highlighted: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: target.symbol)
                .font(.system(size: 13, weight: .medium))
            Text(target.title)
                .font(.system(size: model.tools ? 9 : 11, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(highlighted ? .white : .primary)
        .frame(width: 62)
        .scaleEffect(highlighted ? 1.1 : 1)
    }

    private func labelOffset(index: Int, count: Int) -> CGSize {
        let angle = ConvertRing.centerAngle(of: index, count: count)
        let mid = (inner + outer) / 2
        // Clockwise from 12 o'clock; SwiftUI's y grows downward.
        return CGSize(width: sin(angle) * mid, height: -cos(angle) * mid)
    }
}

/// One annular wedge, centered on its segment's angle.
struct RingSegmentShape: Shape {
    let index: Int
    let count: Int
    let inner: CGFloat
    let outer: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let width = 2 * Double.pi / Double(max(count, 1))
        let gap = count > 1 ? 0.012 : 0
        // SwiftUI angles: 0 = 3 o'clock, clockwise on screen. 12 o'clock = -90°.
        let mid = Double(ConvertRing.centerAngle(of: index, count: count)) - .pi / 2
        let start = Angle.radians(mid - width / 2 + gap), end = Angle.radians(mid + width / 2 - gap)
        var path = Path()
        if count == 1 {
            path.addEllipse(in: CGRect(x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2))
            path.addEllipse(in: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2))
            return path
        }
        path.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}

struct ConvertRingExtension: ExtensionDefinition {
    static let id = "convertRing"
    static let title = "Convert Ring"
    static let subtitle = "Shift-drag files to convert them"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .orange
    static let description = "Start dragging files anywhere and hold Shift: a ring of formats opens at the pointer. Drop on one and the converted copies are saved next to the originals. Hold Option-Shift for tools: compress, remove metadata, merge or split PDFs, read a QR code, zip. Everything runs on your Mac. WebP, MP3, OGG, MKV and WebM need FFmpeg installed."
    static let features: [(icon: String, text: String)] = [
        ("photo", "Images: JPG, PNG, HEIC, AVIF, TIFF, GIF, PDF, BMP"),
        ("waveform", "Audio: M4A, WAV, FLAC, AIFF; video to GIF or audio"),
        ("doc.richtext", "PDF to images or text, SRT ⇄ VTT, documents to text"),
        ("wrench.and.screwdriver", "⌥⇧ for tools: compress, strip metadata, merge, zip"),
        ("xmark.circle", "Drop in the middle or let go elsewhere to cancel")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "arrow.triangle.2.circlepath.circle"
    static let iconPlaceholderColor: Color = .orange
    static func cleanup() { UtilityExtensionKind.convertRing.cleanup() }
}
