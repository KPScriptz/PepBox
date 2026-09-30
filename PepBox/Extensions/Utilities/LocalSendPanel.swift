//
//  LocalSendPanel.swift
//  PepBox
//
//  The device picker for LocalSend: nearby devices appear as they announce
//  themselves; click one to send. Click outside or press Esc to close.
//

import SwiftUI
import AppKit

@Observable
final class LocalSendTransfer {
    enum Phase: Equatable {
        case picking
        case waiting(String)        // waiting for the receiver to accept
        case sending(String, Double)
        case finished(String)
        case failed(String)
    }

    var phase: Phase = .picking
    var urls: [URL] = []

    func send(to device: LocalSendDevice) {
        guard phase == .picking || { if case .failed = phase { return true } else { return false } }() else { return }
        phase = .waiting(device.alias)
        let files = urls
        Task.detached {
            let prepared = LocalSendTransfer.prepare(files)
            let sender = LocalSendSender { [weak self] fraction in
                self?.phase = .sending(device.alias, fraction)
            }
            let outcome = await sender.send(prepared, to: device)
            await MainActor.run {
                switch outcome {
                case .sent(let count):
                    self.phase = .finished("Sent \(count) file\(count == 1 ? "" : "s") to \(device.alias)")
                    HapticFeedback.copy()
                    FlashActivity.shared.show(LiveActivity(id: "localsend-\(UUID())", icon: "paperplane.fill", tint: .green,
                                                           text: "Sent to \(device.alias)", progress: nil))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { LocalSendPanelController.shared.close() }
                case .declined: self.phase = .failed("\(device.alias) declined")
                case .busy: self.phase = .failed("\(device.alias) is busy with another transfer")
                case .failed(let message): self.phase = .failed(message)
                }
            }
        }
    }

    /// Folders are zipped first; LocalSend sends files.
    private static func prepare(_ urls: [URL]) -> [URL] {
        urls.map { url in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { return url }
            let zip = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent + ".zip")
            try? FileManager.default.removeItem(at: zip)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-c", "-k", "--keepParent", url.path, zip.path]
            try? process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? zip : url
        }
    }
}

final class LocalSendPanelController {
    static let shared = LocalSendPanelController()

    private var panel: NSPanel?
    private var monitors: [Any] = []
    private var transfer: LocalSendTransfer?

    func show(_ urls: [URL]) {
        close()
        guard !urls.isEmpty else { return }
        let transfer = LocalSendTransfer()
        transfer.urls = urls
        self.transfer = transfer
        LocalSendDiscovery.shared.start()

        let hosting = NSHostingView(rootView: LocalSendPanelView(discovery: LocalSendDiscovery.shared, transfer: transfer) { [weak self] in
            self?.close()
        })
        hosting.frame.size = NSSize(width: 320, height: 300)

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
            panel.setFrameOrigin(NSPoint(x: visible.midX - 160, y: visible.maxY - 360))
        }
        panel.orderFrontRegardless()
        self.panel = panel

        if let clicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            self?.closeUnlessBusy()
        }) { monitors.append(clicks) }
        if let keys = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            if event.keyCode == 53 { self?.closeUnlessBusy() }
        }) { monitors.append(keys) }
    }

    /// Clicking away mid-transfer shouldn't hide the progress.
    private func closeUnlessBusy() {
        switch transfer?.phase {
        case .waiting, .sending: return
        default: close()
        }
    }

    func close() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        panel?.orderOut(nil)
        panel = nil
        transfer = nil
        LocalSendDiscovery.shared.stop()
    }
}

private struct LocalSendPanelView: View {
    var discovery: LocalSendDiscovery
    var transfer: LocalSendTransfer
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "paperplane.fill").foregroundStyle(.teal)
                Text("LocalSend")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(transfer.urls.count) file\(transfer.urls.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            switch transfer.phase {
            case .picking, .failed:
                if case .failed(let message) = transfer.phase {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
                deviceList
            case .waiting(let name):
                status(icon: "hourglass", "Waiting for \(name) to accept…")
            case .sending(let name, let fraction):
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sending to \(name)…").font(.system(size: 12))
                    ProgressView(value: fraction)
                }
                .frame(maxHeight: .infinity)
            case .finished(let message):
                status(icon: "checkmark.circle.fill", message)
            }
        }
        .padding(16)
        .frame(width: 320, height: 300, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.black.opacity(0.92)))
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var deviceList: some View {
        if let error = discovery.error {
            status(icon: "wifi.exclamationmark", error)
        } else if discovery.devices.isEmpty {
            VStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Looking for nearby devices…")
                    .font(.system(size: 12))
                Text("Open LocalSend on the other device and keep it on the same Wi-Fi.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(discovery.devices) { device in
                        Button { transfer.send(to: device) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: device.symbol)
                                    .font(.system(size: 18))
                                    .frame(width: 28)
                                    .foregroundStyle(.teal)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(device.alias).font(.system(size: 12, weight: .semibold))
                                    Text(device.deviceModel ?? device.ip)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.circle.fill").foregroundStyle(.teal)
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.07)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func status(icon: String, _ text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 24)).foregroundStyle(.teal)
            Text(text).font(.system(size: 12)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
