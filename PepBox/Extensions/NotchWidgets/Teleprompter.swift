//
//  Teleprompter.swift
//  PepBox
//
//  Scrolls a script in the notch, right under the camera.
//

import SwiftUI
import AppKit

@Observable
final class TeleprompterManager {
    static let shared = TeleprompterManager()

    private enum Keys {
        static let script = "teleprompter_script"
        static let speed = "teleprompter_speed"
        static let fontSize = "teleprompter_fontSize"
    }

    var script: String {
        didSet { UserDefaults.standard.set(script, forKey: Keys.script) }
    }
    /// Points per second.
    var speed: Double {
        didSet { UserDefaults.standard.set(speed, forKey: Keys.speed) }
    }
    var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: Keys.fontSize) }
    }

    private(set) var isPlaying = false
    /// How far the script has scrolled up, in points.
    private(set) var offset: CGFloat = 0
    /// Set by the view: how far the script can scroll before its end reaches the top.
    var maxOffset: CGFloat = .greatestFiniteMagnitude

    private var timer: Timer?
    private var lastTick: Date?

    private init() {
        let defaults = UserDefaults.standard
        script = defaults.string(forKey: Keys.script)
            ?? "Paste or type your script with Edit. It scrolls up here, right under your camera, so you keep eye contact while you read."
        let savedSpeed = defaults.double(forKey: Keys.speed)
        speed = savedSpeed > 0 ? savedSpeed : 24
        let savedSize = defaults.double(forKey: Keys.fontSize)
        fontSize = savedSize > 0 ? savedSize : 18
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard !isPlaying else { return }
        if offset >= maxOffset { offset = 0 }
        isPlaying = true
        lastTick = Date()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        lastTick = nil
        isPlaying = false
    }

    func restart() {
        offset = 0
    }

    /// Nudge the script by hand (scroll wheel / trackpad).
    func scroll(by delta: CGFloat) {
        offset = min(max(0, offset + delta), maxOffset)
    }

    private func tick() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTick ?? now)
        lastTick = now
        offset += CGFloat(speed * elapsed)
        if offset >= maxOffset {
            offset = maxOffset
            pause()
        }
    }

    func openEditor() {
        TeleprompterEditorWindow.shared.show(manager: self)
    }
}

struct TeleprompterNotchView: View {
    @Bindable var manager: TeleprompterManager

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 8) {
                Button { manager.toggle() } label: {
                    Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(PepBoxCircleButtonStyle(size: 34, solidFill: .mint))
                .help(manager.isPlaying ? "Pause" : "Play")

                Button { manager.restart() } label: {
                    Image(systemName: "backward.end.fill")
                }
                .buttonStyle(PepBoxCircleButtonStyle(size: 30))
                .help("Back to the start")

                Button { manager.openEditor() } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(PepBoxCircleButtonStyle(size: 30))
                .help("Edit script")
            }

            GeometryReader { viewport in
                Text(manager.script)
                    .font(.system(size: manager.fontSize, weight: .medium))
                    .foregroundStyle(.white)
                    .lineSpacing(4)
                    .frame(width: viewport.size.width, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(
                        GeometryReader { text in
                            Color.clear.onAppear { updateMaxOffset(text: text.size.height) }
                                .onChange(of: text.size.height) { _, height in updateMaxOffset(text: height) }
                        }
                    )
                    .offset(y: -manager.offset)
            }
            .clipped()
            .mask(
                LinearGradient(
                    stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.12),
                            .init(color: .white, location: 0.85), .init(color: .clear, location: 1)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .onScrollWheel { delta in manager.scroll(by: -delta) }

            VStack(spacing: 6) {
                Image(systemName: "hare.fill").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                Slider(value: $manager.speed, in: 5...120)
                    .controlSize(.mini)
                    .frame(width: 70)
                    .help("Speed")
                Image(systemName: "textformat.size").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                Slider(value: $manager.fontSize, in: 12...36)
                    .controlSize(.mini)
                    .frame(width: 70)
                    .help("Text size")
            }
        }
    }

    private func updateMaxOffset(text height: CGFloat) {
        // Stop once the last line has scrolled near the top.
        manager.maxOffset = max(0, height - manager.fontSize * 2)
    }
}

private extension View {
    /// Reports scroll-wheel / trackpad vertical deltas over this view.
    func onScrollWheel(_ action: @escaping (CGFloat) -> Void) -> some View {
        overlay(ScrollWheelCatcher(action: action))
    }
}

private struct ScrollWheelCatcher: NSViewRepresentable {
    let action: (CGFloat) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.action = action
    }

    final class CatcherView: NSView {
        var action: ((CGFloat) -> Void)?
        override func scrollWheel(with event: NSEvent) {
            action?(event.scrollingDeltaY)
        }
    }
}

/// Small window for editing the teleprompter script.
final class TeleprompterEditorWindow {
    static let shared = TeleprompterEditorWindow()
    private var window: NSWindow?

    func show(manager: TeleprompterManager) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Teleprompter Script"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: TeleprompterEditorView(manager: manager))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct TeleprompterEditorView: View {
    @Bindable var manager: TeleprompterManager

    var body: some View {
        TextEditor(text: $manager.script)
            .font(.system(size: 15))
            .padding(12)
            .frame(minWidth: 360, minHeight: 240)
    }
}
