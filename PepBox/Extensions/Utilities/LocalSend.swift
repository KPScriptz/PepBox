//
//  LocalSend.swift
//  PepBox
//
//  Send files to phones and computers running LocalSend (Android, Windows,
//  Linux, iOS, macOS) over the local network, using the open LocalSend v2
//  protocol: devices announce themselves by UDP multicast, then files go over
//  HTTPS to the receiver, who accepts on their device. Nothing leaves the LAN.
//

import Foundation
import Darwin
import UniformTypeIdentifiers
import Observation

// MARK: - Protocol types

struct LocalSendDevice: Identifiable, Equatable, Codable {
    var alias: String
    var version: String?
    var deviceModel: String?
    var deviceType: String?
    var fingerprint: String
    var port: Int?
    var `protocol`: String?
    var download: Bool?
    var announce: Bool?

    /// Filled in from the packet's source address, not part of the JSON.
    var ip: String = ""
    var lastSeen = Date()

    var id: String { fingerprint }

    enum CodingKeys: String, CodingKey {
        case alias, version, deviceModel, deviceType, fingerprint, port, `protocol`, download, announce
    }

    var symbol: String {
        switch deviceType {
        case "mobile": return "iphone"
        case "web": return "globe"
        case "headless", "server": return "server.rack"
        default: return "laptopcomputer"
        }
    }

    var baseURL: URL? {
        URL(string: "\(self.protocol ?? "https")://\(ip):\(port ?? LocalSendProtocol.port)")
    }
}

enum LocalSendProtocol {
    static let port = 53317
    static let multicastGroup = "224.0.0.167"

    /// PepBox's own identity, stable across launches.
    static var me: LocalSendDevice {
        let key = "localSend_fingerprint"
        let fingerprint = UserDefaults.standard.string(forKey: key) ?? {
            let new = UUID().uuidString
            UserDefaults.standard.set(new, forKey: key)
            return new
        }()
        return LocalSendDevice(alias: Host.current().localizedName ?? "PepBox", version: "2.0", deviceModel: "PepBox",
                               deviceType: "desktop", fingerprint: fingerprint, port: port, protocol: "https",
                               download: false, announce: true)
    }

    static func announcement(_ device: LocalSendDevice = me) -> Data {
        (try? JSONEncoder().encode(device)) ?? Data()
    }

    /// Parses a multicast packet. Returns nil for our own announcements and junk.
    static func parse(_ data: Data, from ip: String, myFingerprint: String) -> LocalSendDevice? {
        guard var device = try? JSONDecoder().decode(LocalSendDevice.self, from: data),
              device.fingerprint != myFingerprint, !device.alias.isEmpty else { return nil }
        device.ip = ip
        device.lastSeen = Date()
        return device
    }

    struct FileInfo: Codable, Equatable {
        let id: String
        let fileName: String
        let size: Int64
        let fileType: String
    }

    static func fileInfo(for url: URL, id: String) -> FileInfo {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        return FileInfo(id: id, fileName: url.lastPathComponent, size: size, fileType: mime)
    }

    /// Body for POST /api/localsend/v2/prepare-upload.
    static func prepareUploadBody(files: [FileInfo], sender: LocalSendDevice = me) -> Data {
        var info = sender
        info.announce = nil
        let body: [String: Any] = [
            "info": (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(info))) ?? [:],
            "files": Dictionary(uniqueKeysWithValues: files.map { file in
                (file.id, ["id": file.id, "fileName": file.fileName, "size": file.size, "fileType": file.fileType] as [String: Any])
            })
        ]
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    struct PrepareResponse: Decodable {
        let sessionId: String
        let files: [String: String]  // fileId → token
    }
}

// MARK: - Discovery (UDP multicast)

@Observable
final class LocalSendDiscovery {
    static let shared = LocalSendDiscovery()

    private(set) var devices: [LocalSendDevice] = []
    private(set) var error: String?

    private var socketFD: Int32 = -1
    private var isRunning = false
    private var announceTimer: Timer?

    func start() {
        guard !isRunning else { announce(); return }
        isRunning = true
        error = nil
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { fail("Couldn't open the network"); return }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &yes, socklen_t(MemoryLayout<Int32>.size))
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(UInt16(LocalSendProtocol.port).bigEndian)
        address.sin_addr = in_addr(s_addr: INADDR_ANY)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0 else { close(fd); fail("Port \(LocalSendProtocol.port) is busy"); return }

        var membership = ip_mreq(imr_multiaddr: in_addr(s_addr: inet_addr(LocalSendProtocol.multicastGroup)),
                                 imr_interface: in_addr(s_addr: INADDR_ANY))
        setsockopt(fd, IPPROTO_IP, IP_ADD_MEMBERSHIP, &membership, socklen_t(MemoryLayout<ip_mreq>.size))
        socketFD = fd

        let myFingerprint = LocalSendProtocol.me.fingerprint
        Thread.detachNewThread { [weak self] in self?.receiveLoop(fd: fd, myFingerprint: myFingerprint) }

        announce()
        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            self?.announce()
            self?.dropStale()
        }
        RunLoop.main.add(timer, forMode: .common)
        announceTimer = timer
    }

    func stop() {
        isRunning = false
        announceTimer?.invalidate()
        announceTimer = nil
        if socketFD >= 0 { close(socketFD) }
        socketFD = -1
    }

    private func fail(_ message: String) {
        isRunning = false
        error = message
    }

    private func announce() {
        guard socketFD >= 0 else { return }
        var group = sockaddr_in()
        group.sin_family = sa_family_t(AF_INET)
        group.sin_port = in_port_t(UInt16(LocalSendProtocol.port).bigEndian)
        group.sin_addr = in_addr(s_addr: inet_addr(LocalSendProtocol.multicastGroup))
        let data = LocalSendProtocol.announcement()
        _ = data.withUnsafeBytes { bytes in
            withUnsafePointer(to: &group) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(socketFD, bytes.baseAddress, data.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    private func receiveLoop(fd: Int32, myFingerprint: String) {
        var buffer = [UInt8](repeating: 0, count: 65_536)
        while isRunning && socketFD == fd {
            var source = sockaddr_in()
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = withUnsafeMutablePointer(to: &source) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { recvfrom(fd, &buffer, buffer.count, 0, $0, &length) }
            }
            guard count > 0 else { continue }
            var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &source.sin_addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
            let ip = String(cString: ipBuffer)
            guard let device = LocalSendProtocol.parse(Data(buffer[0..<count]), from: ip, myFingerprint: myFingerprint) else { continue }
            DispatchQueue.main.async { [weak self] in self?.upsert(device) }
        }
    }

    private func upsert(_ device: LocalSendDevice) {
        if let index = devices.firstIndex(where: { $0.fingerprint == device.fingerprint }) {
            devices[index] = device
        } else {
            devices.append(device)
            devices.sort { $0.alias.localizedCaseInsensitiveCompare($1.alias) == .orderedAscending }
        }
    }

    private func dropStale() {
        devices.removeAll { Date().timeIntervalSince($0.lastSeen) > 30 }
    }
}

// MARK: - Sending (HTTPS to the receiver)

final class LocalSendSender: NSObject, URLSessionTaskDelegate {
    enum Outcome: Equatable {
        case sent(Int)
        case declined
        case busy
        case failed(String)
    }

    private var session: URLSession!
    private var totalBytes: Int64 = 1
    private var sentBytes: [Int: Int64] = [:]
    private let onProgress: (Double) -> Void

    init(onProgress: @escaping (Double) -> Void) {
        self.onProgress = onProgress
        super.init()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 180  // the receiver has to tap Accept
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    /// LocalSend devices use self-signed certificates, so this session (used only for them) accepts any.
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async
        -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        if let trust = challenge.protectionSpace.serverTrust {
            return (.useCredential, URLCredential(trust: trust))
        }
        return (.performDefaultHandling, nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        sentBytes[task.taskIdentifier] = totalBytesSent
        let fraction = Double(sentBytes.values.reduce(0, +)) / Double(max(1, totalBytes))
        DispatchQueue.main.async { self.onProgress(min(1, fraction)) }
    }

    func send(_ urls: [URL], to device: LocalSendDevice) async -> Outcome {
        defer { session.finishTasksAndInvalidate() }
        guard let base = device.baseURL else { return .failed("Bad address") }
        let files = urls.enumerated().map { LocalSendProtocol.fileInfo(for: $1, id: "file\($0)") }
        totalBytes = max(1, files.reduce(0) { $0 + $1.size })

        var prepare = URLRequest(url: base.appendingPathComponent("api/localsend/v2/prepare-upload"))
        prepare.httpMethod = "POST"
        prepare.setValue("application/json", forHTTPHeaderField: "Content-Type")
        prepare.httpBody = LocalSendProtocol.prepareUploadBody(files: files)

        let response: LocalSendProtocol.PrepareResponse
        do {
            let (data, reply) = try await session.data(for: prepare)
            switch (reply as? HTTPURLResponse)?.statusCode ?? 0 {
            case 200: break
            case 204: return .sent(0)
            case 403: return .declined
            case 409, 429: return .busy
            case let code: return .failed("Error \(code)")
            }
            response = try JSONDecoder().decode(LocalSendProtocol.PrepareResponse.self, from: data)
        } catch {
            return .failed(error.localizedDescription)
        }

        var sent = 0
        for (file, url) in zip(files, urls) {
            guard let token = response.files[file.id] else { continue }  // receiver skipped it
            var components = URLComponents(url: base.appendingPathComponent("api/localsend/v2/upload"), resolvingAgainstBaseURL: false)
            components?.queryItems = [
                URLQueryItem(name: "sessionId", value: response.sessionId),
                URLQueryItem(name: "fileId", value: file.id),
                URLQueryItem(name: "token", value: token)
            ]
            guard let uploadURL = components?.url else { continue }
            var upload = URLRequest(url: uploadURL)
            upload.httpMethod = "POST"
            upload.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            do {
                let (_, reply) = try await session.upload(for: upload, fromFile: url)
                guard (reply as? HTTPURLResponse)?.statusCode == 200 else { return .failed("Upload of \(file.fileName) failed") }
                sent += 1
            } catch {
                return .failed(error.localizedDescription)
            }
        }
        return .sent(sent)
    }
}
