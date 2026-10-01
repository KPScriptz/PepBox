//
//  LocalSendReceiver.swift
//  PepBox
//
//  Receive files from LocalSend devices. PepBox announces itself on the LAN,
//  asks you to accept each incoming transfer, saves accepted files to
//  Downloads and puts them on the shelf. The receiver speaks plain HTTP (the
//  LocalSend protocol allows it); senders connect with whatever PepBox announces.
//

import Foundation
import Network
import AppKit
import SwiftUI

final class LocalSendReceiver {
    static let shared = LocalSendReceiver()

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "PepBox.LocalSendReceiver")

    /// The one transfer being received: file id → (name, token, size).
    private struct Session {
        let id: String
        let sender: String
        var files: [String: (name: String, token: String)]
        var received: [URL] = []
    }
    private var session: Session?

    var isRunning: Bool { listener != nil }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            guard listener == nil else { return }
            do {
                let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(integerLiteral: UInt16(LocalSendProtocol.port)))
                listener.newConnectionHandler = { [weak self] connection in self?.handle(connection) }
                listener.start(queue: queue)
                self.listener = listener
                LocalSendDiscovery.shared.receiving = true
                LocalSendDiscovery.shared.start()
            } catch {
                print("📨 LocalSend receiver failed to start: \(error)")
            }
        } else {
            listener?.cancel()
            listener = nil
            LocalSendDiscovery.shared.receiving = false
            LocalSendDiscovery.shared.stop()
        }
    }

    // MARK: Connections

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        let reader = HTTPRequestReader()
        var head: HTTPRequestHead?
        var body = Data()
        var fileHandle: FileHandle?
        var fileURL: URL?
        var rejected = false

        func reply(_ status: Int, _ json: Data? = nil) {
            connection.send(content: HTTPRequestReader.response(status: status, json: json), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }

        func receive() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { [weak self] data, _, isComplete, error in
                guard let self else { return }
                for event in reader.feed(data ?? Data()) {
                    switch event {
                    case .head(let parsed):
                        head = parsed
                        if parsed.path.hasSuffix("/upload") {
                            // Start streaming to disk right away if the token checks out.
                            if let target = self.uploadTarget(for: parsed) {
                                FileManager.default.createFile(atPath: target.path, contents: nil)
                                fileHandle = try? FileHandle(forWritingTo: target)
                                fileURL = target
                            } else {
                                rejected = true
                            }
                        }
                    case .body(let chunk):
                        if let fileHandle {
                            try? fileHandle.write(contentsOf: chunk)
                        } else if !rejected, body.count < 1_000_000 {
                            body.append(chunk)
                        }
                    case .end:
                        try? fileHandle?.close()
                        guard let head else { reply(400); return }
                        if rejected { reply(403); return }
                        self.route(head, body: body, savedFile: fileURL, reply: reply)
                        return
                    case .malformed:
                        reply(400)
                        return
                    }
                }
                if isComplete || error != nil {
                    try? fileHandle?.close()
                    connection.cancel()
                    return
                }
                receive()
            }
        }
        receive()
    }

    private func route(_ head: HTTPRequestHead, body: Data, savedFile: URL?, reply: @escaping (Int, Data?) -> Void) {
        switch (head.method, head.path) {
        case ("GET", "/api/localsend/v2/info"), ("POST", "/api/localsend/v2/register"):
            reply(200, Self.myInfo())
        case ("POST", "/api/localsend/v2/prepare-upload"):
            prepareUpload(body, reply: reply)
        case ("POST", "/api/localsend/v2/upload"):
            finishedFile(savedFile)
            reply(200, nil)
        case ("POST", "/api/localsend/v2/cancel"):
            session = nil
            reply(200, nil)
        default:
            reply(404, nil)
        }
    }

    private static func myInfo() -> Data {
        var me = LocalSendProtocol.me
        me.protocol = "http"
        me.download = false
        me.announce = nil
        return (try? JSONEncoder().encode(me)) ?? Data()
    }

    // MARK: Transfers

    private func prepareUpload(_ body: Data, reply: @escaping (Int, Data?) -> Void) {
        guard session == nil else { reply(409, nil); return }
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let info = json["info"] as? [String: Any],
              let files = json["files"] as? [String: [String: Any]], !files.isEmpty else { reply(400, nil); return }
        let sender = info["alias"] as? String ?? "A device"
        let names = files.values.compactMap { $0["fileName"] as? String }
        let totalSize = files.values.compactMap { ($0["size"] as? NSNumber)?.int64Value }.reduce(0, +)

        DispatchQueue.main.async {
            LocalSendIncomingPrompt.ask(sender: sender, fileNames: names, totalSize: totalSize) { [weak self] accepted in
                self?.queue.async {
                    guard let self, accepted else { reply(403, nil); return }
                    var entries: [String: (name: String, token: String)] = [:]
                    for (id, file) in files {
                        let name = (file["fileName"] as? String).map { ($0 as NSString).lastPathComponent } ?? id
                        entries[id] = (name.isEmpty ? id : name, UUID().uuidString)
                    }
                    let session = Session(id: UUID().uuidString, sender: sender, files: entries)
                    self.session = session
                    let response: [String: Any] = ["sessionId": session.id, "files": entries.mapValues(\.token)]
                    reply(200, try? JSONSerialization.data(withJSONObject: response))
                }
            }
        }
    }

    /// Where an upload with a valid session and token is written (unique name in Downloads).
    private func uploadTarget(for head: HTTPRequestHead) -> URL? {
        guard let session, head.query["sessionId"] == session.id,
              let fileId = head.query["fileId"], let entry = session.files[fileId],
              head.query["token"] == entry.token else { return nil }
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        var target = downloads.appendingPathComponent(entry.name)
        var n = 2
        while FileManager.default.fileExists(atPath: target.path) {
            let base = (entry.name as NSString).deletingPathExtension, ext = (entry.name as NSString).pathExtension
            target = downloads.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
            n += 1
        }
        return target
    }

    private func finishedFile(_ url: URL?) {
        guard var session, let url else { return }
        session.received.append(url)
        self.session = session
        if session.received.count >= session.files.count {
            self.session = nil
            let received = session.received
            DispatchQueue.main.async {
                PepBoxState.shared.addItems(from: received)
                HapticFeedback.copy()
                FlashActivity.shared.show(LiveActivity(id: "localsend-in-\(UUID())", icon: "tray.and.arrow.down.fill", tint: .teal,
                                                       text: "\(received.count) from \(session.sender)", progress: nil), for: 4)
            }
        }
    }
}

/// Accept / Decline for an incoming LocalSend transfer. Declines by itself after a minute.
enum LocalSendIncomingPrompt {
    private static var panel: NSPanel?

    static func ask(sender: String, fileNames: [String], totalSize: Int64, completion: @escaping (Bool) -> Void) {
        panel?.orderOut(nil)
        var answered = false
        func answer(_ accepted: Bool) {
            guard !answered else { return }
            answered = true
            panel?.orderOut(nil)
            panel = nil
            completion(accepted)
        }
        let size = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        let summary = fileNames.count == 1 ? fileNames[0] : "\(fileNames.count) files"
        let view = VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill").foregroundStyle(.teal)
                Text("\(sender) wants to send you").font(.system(size: 12, weight: .semibold))
            }
            Text("\(summary) · \(size)").font(.system(size: 12)).lineLimit(2)
            HStack {
                Button("Decline") { answer(false) }
                Spacer()
                Button("Accept") { answer(true) }.keyboardShortcut(.defaultAction)
            }
            .controlSize(.regular)
        }
        .padding(16)
        .frame(width: 300)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black.opacity(0.92)))
        .environment(\.colorScheme, .dark)

        let hosting = NSHostingView(rootView: view)
        hosting.frame.size = hosting.fittingSize
        let newPanel = NSPanel(contentRect: hosting.frame, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        newPanel.level = .popUpMenu
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = true
        newPanel.contentView = hosting
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        if let visible = NSScreen.main?.visibleFrame {
            newPanel.setFrameOrigin(NSPoint(x: visible.midX - hosting.frame.width / 2, y: visible.maxY - hosting.frame.height - 60))
        }
        newPanel.orderFrontRegardless()
        panel = newPanel
        NSSound(named: "Ping")?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { answer(false) }
    }
}

struct LocalSendExtension: ExtensionDefinition {
    static let id = "localSend"
    static let title = "LocalSend"
    static let subtitle = "AirDrop for every device, no cloud"
    static let category: ExtensionGroup = .productivity
    static let categoryColor: Color = .teal
    static let description = "Send files to and receive files from phones and computers running the free LocalSend app (Android, Windows, Linux, iPhone, Mac), directly over your Wi-Fi. Sending is in Quick Actions and the shelf's right-click menu. Turn this on to receive: PepBox asks before accepting anything, then saves files to Downloads and puts them on your shelf. Received transfers use unencrypted HTTP on your local network."
    static let features: [(icon: String, text: String)] = [
        ("paperplane.fill", "Send from Quick Actions or right-click"),
        ("tray.and.arrow.down.fill", "Receive to Downloads and the shelf"),
        ("hand.raised.fill", "Asks before accepting anything"),
        ("wifi", "Local network only, no cloud")
    ]
    static var screenshotURL: URL? { nil }
    static var iconURL: URL? { nil }
    static let iconPlaceholder = "paperplane.fill"
    static let iconPlaceholderColor: Color = .teal
    static func cleanup() { UtilityExtensionKind.localSend.cleanup() }
}
