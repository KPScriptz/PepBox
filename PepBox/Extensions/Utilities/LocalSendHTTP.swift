//
//  LocalSendHTTP.swift
//  PepBox
//
//  A small incremental HTTP/1.1 request reader for the LocalSend receiver:
//  headers first, then the body in pieces (Content-Length or chunked), so
//  large uploads stream to disk instead of into memory.
//

import Foundation

struct HTTPRequestHead: Equatable {
    let method: String
    let path: String
    let query: [String: String]
    let headers: [String: String]  // lowercased names

    var contentLength: Int? { headers["content-length"].flatMap(Int.init) }
    var isChunked: Bool { headers["transfer-encoding"]?.lowercased().contains("chunked") == true }
}

final class HTTPRequestReader {
    enum Event: Equatable {
        case head(HTTPRequestHead)
        case body(Data)
        case end
        case malformed
    }

    private var buffer = Data()
    private var head: HTTPRequestHead?
    private var remaining = 0          // Content-Length bytes still expected
    private enum ChunkState { case size, data(Int), dataEnd }
    private var chunkState = ChunkState.size
    private var finished = false
    private static let headLimit = 64 * 1024

    func feed(_ data: Data) -> [Event] {
        guard !finished else { return [] }
        buffer.append(data)
        var events: [Event] = []

        if head == nil {
            guard let range = buffer.range(of: Data("\r\n\r\n".utf8)) else {
                return buffer.count > Self.headLimit ? finish(with: .malformed, into: events) : events
            }
            guard let parsed = Self.parseHead(buffer[..<range.lowerBound]) else { return finish(with: .malformed, into: events) }
            head = parsed
            buffer.removeSubrange(..<range.upperBound)
            events.append(.head(parsed))
            if parsed.isChunked {
                chunkState = .size
            } else {
                remaining = parsed.contentLength ?? 0
                if remaining < 0 { return finish(with: .malformed, into: events) }
                if remaining == 0 { return finish(with: .end, into: events) }
            }
        }

        guard let head else { return events }
        if head.isChunked {
            return readChunks(into: events)
        }
        if !buffer.isEmpty {
            let take = min(remaining, buffer.count)
            events.append(.body(buffer.prefix(take)))
            buffer.removeFirst(take)
            remaining -= take
        }
        return remaining == 0 ? finish(with: .end, into: events) : events
    }

    private func readChunks(into events: [Event]) -> [Event] {
        var events = events
        while true {
            switch chunkState {
            case .size:
                guard let lineEnd = buffer.range(of: Data("\r\n".utf8)) else {
                    return buffer.count > 1024 ? finish(with: .malformed, into: events) : events  // a size line never runs this long
                }
                let sizeText = String(decoding: buffer[..<lineEnd.lowerBound], as: UTF8.self)
                    .split(separator: ";").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                guard let size = Int(sizeText, radix: 16), size >= 0 else { return finish(with: .malformed, into: events) }
                buffer.removeSubrange(..<lineEnd.upperBound)
                if size == 0 { return finish(with: .end, into: events) }  // trailers are ignored
                chunkState = .data(size)
            case .data(let left):
                guard !buffer.isEmpty else { return events }
                let take = min(left, buffer.count)
                events.append(.body(buffer.prefix(take)))
                buffer.removeFirst(take)
                chunkState = left - take > 0 ? .data(left - take) : .dataEnd
            case .dataEnd:
                // Each chunk's data is followed by CRLF.
                guard buffer.count >= 2 else { return events }
                buffer.removeFirst(2)
                chunkState = .size
            }
        }
    }

    private func finish(with event: Event, into events: [Event]) -> [Event] {
        finished = true
        return events + [event]
    }

    static func parseHead(_ data: Data) -> HTTPRequestHead? {
        let lines = String(decoding: data, as: UTF8.self).components(separatedBy: "\r\n")
        let requestLine = lines.first?.split(separator: " ") ?? []
        guard requestLine.count >= 2 else { return nil }
        let target = String(requestLine[1])
        let components = URLComponents(string: target)
        var query: [String: String] = [:]
        components?.queryItems?.forEach { query[$0.name] = $0.value ?? "" }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[line[..<colon].lowercased().trimmingCharacters(in: .whitespaces)] =
                line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        return HTTPRequestHead(method: String(requestLine[0]), path: components?.path ?? target, query: query, headers: headers)
    }

    static func response(status: Int, json: Data? = nil) -> Data {
        let reason = [200: "OK", 204: "No Content", 400: "Bad Request", 403: "Forbidden", 404: "Not Found",
                      409: "Conflict", 500: "Internal Server Error"][status] ?? "OK"
        let body = json ?? Data()
        var head = "HTTP/1.1 \(status) \(reason)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n"
        if json != nil { head += "Content-Type: application/json\r\n" }
        head += "\r\n"
        return Data(head.utf8) + body
    }
}
