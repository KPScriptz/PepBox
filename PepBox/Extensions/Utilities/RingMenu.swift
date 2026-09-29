//
//  RingMenu.swift
//  PepBox
//
//  A ring of quick actions that opens at the pointer (⌥⇧Space).
//

import SwiftUI
import AppKit
import Carbon.HIToolbox

struct RingAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let tint: Color
    let perform: () -> Void
}

final class RingMenuController {
    static let shared = RingMenuController()

    private var hotKey: GlobalHotKey?
    private var panel: NSPanel?
    private var clickMonitor: Any?
    private var keyMonitor: Any?

    func setEnabled(_ enabled: Bool) {
        if enabled {
            guard hotKey == nil else { return }
            let shortcut = ExtensionShortcuts.load(ExtensionShortcuts.ringKey, default: ExtensionShortcuts.ringDefault)
            hotKey = GlobalHotKey(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in
                DispatchQueue.main.async { self?.toggle() }
            }
        } else {
            hotKey = nil
            close()
        }
    }

    /// Re-registers the hotkey after the shortcut changed in the extension's options.
    func reloadShortcut() {
        guard hotKey != nil else { return }
        hotKey = nil
        setEnabled(true)
    }

    func toggle() {
        panel == nil ? open() : close()
    }

    private func open() {
        let size: CGFloat = 280
        let mouse = NSEvent.mouseLocation
        var frame = NSRect(x: mouse.x - size / 2, y: mouse.y - size / 2, width: size, height: size)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
            // Keep the whole ring on screen near edges.
            let visible = screen.visibleFrame
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - size)
            frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - size)
        }

        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: RingMenuView(actions: actions()) { [weak self] action in
            self?.close()
            // Let the ring disappear before the action opens its own UI.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { action.perform() }
        })
        panel.orderFrontRegardless()
        self.panel = panel

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == UInt16(kVK_Escape) { self?.close() }
        }
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        clickMonitor = nil
        keyMonitor = nil
    }

    private func actions() -> [RingAction] {
        [
            RingAction(id: "clipboard", title: "Clipboard", icon: "doc.on.clipboard", tint: .blue) {
                ClipboardWindowController.shared.toggle()
            },
            RingAction(id: "shelf", title: "Shelf", icon: "tray.full", tint: .indigo) {
                let mouse = NSEvent.mouseLocation
                let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
                if let screen {
                    withAnimation(PepBoxAnimation.expandOpen(for: screen)) {
                        PepBoxState.shared.expandShelf(for: screen.displayID)
                    }
                }
            },
            RingAction(id: "basket", title: "Basket", icon: "basket", tint: .purple) {
                FloatingBasketWindowController.shared.showBasket()
            },
            RingAction(id: "screenshot", title: "Screenshot", icon: "camera.viewfinder", tint: .teal) {
                RingMenuController.screenshotToShelf()
            },
            RingAction(id: "color", title: "Color", icon: "eyedropper", tint: .pink) {
                NSColorSampler().show { color in
                    guard let hex = color?.usingColorSpace(.sRGB).map(RingMenuController.hexString) else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(hex, forType: .string)
                    HapticFeedback.copy()
                }
            },
            RingAction(id: "pomodoro", title: PomodoroManager.shared.isRunning ? "Pause" : "Focus", icon: "timer", tint: .red) {
                PomodoroManager.shared.toggle()
            },
            RingAction(id: "awake", title: CaffeineManager.shared.isActive ? "Allow Sleep" : "Stay Awake", icon: "eyes", tint: .orange) {
                CaffeineManager.shared.toggle()
            },
            RingAction(id: "settings", title: "Settings", icon: "gearshape", tint: .gray) {
                SettingsWindowController.shared.showSettings()
            }
        ]
    }

    /// macOS's own area screenshot (⌘⇧4); the next capture goes on the shelf. Running
    /// screencapture ourselves would need PepBox to have Screen Recording permission,
    /// otherwise the image only shows the wallpaper.
    private static func screenshotToShelf() {
        guard AXIsProcessTrusted() else {
            PermissionManager.shared.requestAccessibilityForUserAction()
            return
        }
        ScreenshotWatcher.shared.captureNext()
        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_4), keyDown: keyDown) else { continue }
            event.flags = [.maskCommand, .maskShift]
            event.post(tap: .cghidEventTap)
        }
    }

    private static func hexString(_ color: NSColor) -> String {
        let r = Int((color.redComponent * 255).rounded())
        let g = Int((color.greenComponent * 255).rounded())
        let b = Int((color.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

struct RingMenuView: View {
    let actions: [RingAction]
    let onSelect: (RingAction) -> Void

    @State private var hovered: String?
    @State private var appeared = false

    private let radius: CGFloat = 96

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: radius * 2 + 64, height: radius * 2 + 64)
                .shadow(color: .black.opacity(0.25), radius: 16, y: 6)

            Text(actions.first(where: { $0.id == hovered })?.title ?? "")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                let angle = Angle.degrees(Double(index) / Double(actions.count) * 360 - 90)
                Button { onSelect(action) } label: {
                    Image(systemName: action.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(action.tint.opacity(hovered == action.id ? 1 : 0.8)))
                        .scaleEffect(hovered == action.id ? 1.12 : 1)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) { hovered = hovering ? action.id : (hovered == action.id ? nil : hovered) }
                }
                .offset(x: cos(angle.radians) * radius, y: sin(angle.radians) * radius)
            }
        }
        .frame(width: 280, height: 280)
        .scaleEffect(appeared ? 1 : 0.6)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { appeared = true } }
    }
}
