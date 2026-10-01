// Scenarios: the LocalSend receiver's HTTP reader under random splits, chunking and
// hostile input; and LocalSend discovery/prepare-upload parsing.

import Foundation

struct ReaderRun {
    var head: HTTPRequestHead?
    var body = Data()
    var ends = 0
    var malformed = 0
    var eventsAfterFinish = 0
    var peakBuffered = 0
}

/// Feeds `bytes` in pieces whose sizes come from `sizes` (cycled), like TCP reads.
func feedReader(_ bytes: Data, pieceSizes: [Int]) -> ReaderRun {
    let reader = HTTPRequestReader()
    var run = ReaderRun()
    var index = bytes.startIndex, piece = 0
    var finished = false
    while index < bytes.endIndex {
        let size = max(1, pieceSizes[piece % pieceSizes.count]); piece += 1
        let end = min(index + size, bytes.endIndex)
        let events = reader.feed(Data(bytes[index..<end]))
        Crumb.progress &+= 1
        if finished && !events.isEmpty { run.eventsAfterFinish += events.count }
        for event in events {
            switch event {
            case .head(let h): run.head = h
            case .body(let d): run.body.append(d)
            case .end: run.ends += 1; finished = true
            case .malformed: run.malformed += 1; finished = true
            }
        }
        index = end
    }
    return run
}

private func chunkedBody(_ body: Data, _ rng: inout RNG) -> Data {
    var out = Data()
    var offset = 0
    while offset < body.count {
        let size = min(body.count - offset, rng.pick([1, 2, 7, 100, 4096, 65_536, rng.range(1...300_000)]))
        var sizeLine = String(size, radix: 16)
        if rng.chance(0.2) { sizeLine = sizeLine.uppercased() }
        if rng.chance(0.1) { sizeLine = "000" + sizeLine }
        if rng.chance(0.15) { sizeLine += ";name=\"v\"" }
        out += Data((sizeLine + "\r\n").utf8) + body[offset..<(offset + size)] + Data("\r\n".utf8)
        offset += size
    }
    out += Data((rng.chance(0.3) ? "0\r\nX-Trailer: 1\r\n\r\n" : "0\r\n\r\n").utf8)
    return out
}

private func randomPieces(_ rng: inout RNG) -> [Int] {
    switch rng.int(5) {
    case 0: return [1]
    case 1: return [rng.range(1...16)]
    case 2: return (0..<8).map { _ in rng.range(1...70_000) }
    case 3: return [262_144]   // the receiver reads up to 256 KB at a time
    default: return (0..<16).map { _ in rng.pick([1, 2, 3, 5, 8, 1460, 16_384, 65_536]) }
    }
}

func scenarioHTTP(start: Int) {
    var rng = RNG(0x4777)
    var totalBytes = 0
    let validCases = 1_500
    // 1) Valid uploads with Content-Length or chunked bodies, split at random points.
    for index in 0..<validCases {
        if index < start { continue }
        var caseRNG = RNG(UInt64(index) &+ 0x1000)
        let pieces = randomPieces(&caseRNG)
        var length = caseRNG.pick([0, 0, 1, 2, 13, 1000, caseRNG.range(0...70_000), caseRNG.range(0...1_048_576)])
        if pieces.max()! < 100 { length = min(length, 20_000) }   // byte-at-a-time reads: keep the case quick
        let body = caseRNG.bytes(length)
        let chunked = caseRNG.chance(0.4)
        let path = "/api/localsend/v2/upload?sessionId=s\(index)&fileId=f\(index % 7)&token=t%20\(index)"
        var head = "POST \(path) HTTP/1.1\r\nHost: 192.168.1.\(index % 250)\r\n"
        head += chunked ? "Transfer-Encoding: chunked\r\n" : (length == 0 && caseRNG.chance(0.5) ? "" : "Content-Length: \(length)\r\n")
        if caseRNG.chance(0.2) { head += "X-Pad: " + String(repeating: "p", count: caseRNG.range(0...20_000)) + "\r\n" }
        head += "\r\n"
        var raw = Data(head.utf8) + (chunked ? chunkedBody(body, &caseRNG) : body)
        if caseRNG.chance(0.2) { raw += Data("GET /next HTTP/1.1\r\n\r\n".utf8) }   // pipelined junk after the body is ignored
        Crumb.set(index, "http valid case \(index): \(chunked ? "chunked" : "length") \(length) bytes")
        let run = feedReader(raw, pieceSizes: pieces)
        totalBytes += raw.count
        expectEq(run.head?.path, "/api/localsend/v2/upload", "http path case \(index)")
        expectEq(run.head?.query["token"], "t \(index)", "http query case \(index)")
        check(run.body == body, "http body round-trip case \(index) (\(chunked ? "chunked" : "length") \(length) bytes, got \(run.body.count))")
        expectEq(run.ends, 1, "http exactly one end case \(index)")
        expectEq(run.malformed, 0, "http not malformed case \(index)")
        expectEq(run.eventsAfterFinish, 0, "http silent after end case \(index)")
    }

    // 2) Hostile and malformed requests: must never crash; must end or reject.
    let hostile: [(String, Data, Bool)] = [   // name, bytes, must be rejected as malformed
        ("negative content-length", Data("POST /u HTTP/1.1\r\nContent-Length: -5\r\n\r\nhello".utf8), true),
        ("negative content-length, no body yet", Data("POST /u HTTP/1.1\r\nContent-Length: -1\r\n\r\n".utf8), true),
        ("negative chunk size", Data("POST /u HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n-5\r\nhello\r\n0\r\n\r\n".utf8), true),
        ("plus-signed chunk size", Data("POST /u HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n+5\r\nhello\r\n0\r\n\r\n".utf8), false),
        ("chunk size overflow", Data("POST /u HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\nffffffffffffffffff\r\n".utf8), true),
        ("bad chunk size", Data("POST /u HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\nzz\r\n".utf8), true),
        ("no request line", Data("\r\n\r\n".utf8), true),
        ("binary garbage", rng.bytes(5_000) + Data("\r\n\r\n".utf8), false),
        ("content-length text", Data("POST /u HTTP/1.1\r\nContent-Length: lots\r\n\r\nabc".utf8), false),
        ("huge content-length", Data("POST /u HTTP/1.1\r\nContent-Length: 99999999999999999999999\r\n\r\nabc".utf8), false),
        ("header without colon", Data("GET / HTTP/1.1\r\nnocolon\r\n:empty\r\n\r\n".utf8), false),
        ("invalid utf8 head", Data([0x47, 0x45, 0x54, 0x20, 0xFF, 0xFE, 0x20, 0x48, 0x0D, 0x0A, 0x0D, 0x0A]), false),
        ("percent junk path", Data("GET /%zz%%?a=%E2%82&b HTTP/1.1\r\n\r\n".utf8), false)
    ]
    for (offset, (name, raw, mustReject)) in hostile.enumerated() {
        for (variant, pieces) in [[1], [3], [100_000]].enumerated() {
            guard step(validCases + offset * 3 + variant, "http hostile: \(name) pieces \(pieces)") else { continue }
            let run = feedReader(raw, pieceSizes: pieces)
            check(run.ends + run.malformed <= 1, "\(name): more than one terminal event")
            if mustReject { expectEq(run.malformed, 1, "\(name) is rejected (pieces \(pieces))") }
            check(run.body.count <= raw.count, "\(name): body larger than input")
        }
    }

    // 3) Header bomb: 1 MB of header without the blank line, fed in network-sized pieces.
    if step(validCases + 100, "http header bomb") {
        let bomb = Data(("POST /u HTTP/1.1\r\n" + String(repeating: "X-A: b\r\n", count: 131_072)).utf8)
        let run = feedReader(bomb, pieceSizes: [1460])
        expectEq(run.malformed, 1, "header bomb is rejected")
        let oneShot = feedReader(bomb + Data("\r\n".utf8), pieceSizes: [bomb.count + 2])
        if oneShot.malformed == 0 { note("a >64 KB header that arrives in one read is accepted (limit only applies while waiting)") }
    }

    // 4) A chunk-size line that never ends: does the reader buffer it forever?
    if step(validCases + 101, "http endless chunk-size line") {
        let reader = HTTPRequestReader()
        _ = reader.feed(Data("POST /u HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n".utf8))
        var rejected = false, fed = 0
        let piece = Data(repeating: UInt8(ascii: "0"), count: 65_536)
        while fed < 8 * 1_048_576 && !rejected {   // 8 MB of "000…"
            rejected = reader.feed(piece).contains(.malformed)
            fed += piece.count
        }
        check(rejected, "chunked size line without CRLF is buffered without limit (fed \(fed / 1_048_576) MB, never rejected)")
    }
    _ = rng.next()
    note("\(validCases - start) valid requests (\(totalBytes / 1_048_576) MB) round-tripped; \(hostile.count) hostile shapes × 3 split patterns")
}

// MARK: - LocalSend protocol

func scenarioLocalSend(start: Int) {
    var rng = RNG(0x105E)
    let keys = ["alias", "version", "deviceModel", "deviceType", "fingerprint", "port", "protocol", "download", "announce", "extra"]
    func randomValue(_ rng: inout RNG, depth: Int = 0) -> Any {
        switch rng.int(depth > 2 ? 6 : 8) {
        case 0: return rng.pick(["Pixel", "", " ", "日本", "👨‍👩‍👧‍👦", "a\u{0}b", "\u{202E}evil", "me"])
        case 1: return String(repeating: "A", count: rng.pick([1, 255, 4_096, 65_536]))
        case 2: return rng.pick([0, -1, 53317, 65_536, Int.max, Int.min]) as Int
        case 3: return rng.pick([0.5, -0.0, 1e308])
        case 4: return rng.chance(0.5)
        case 5: return NSNull()
        case 6: return [randomValue(&rng, depth: depth + 1), randomValue(&rng, depth: depth + 1)]
        default: return ["nested": randomValue(&rng, depth: depth + 1)]
        }
    }
    var parsed = 0, ownFiltered = 0
    for index in 0..<4_000 {
        var dict: [String: Any] = [:]
        for key in keys where rng.chance(0.75) { dict[key] = randomValue(&rng) }
        // Most packets are real devices; the rest are hostile or broken.
        if rng.chance(0.8) { dict["alias"] = rng.pick(["Pixel 9", "Kyle's iPhone", "", String(repeating: "Ω", count: index == 7 ? 1_048_576 : 300)]) }
        if rng.chance(0.8) { dict["fingerprint"] = rng.pick(["abc", "me", "", "fp-\(index % 50)"]) }
        if rng.chance(0.6) { for key in ["version", "deviceModel", "deviceType", "protocol"] { dict[key] = rng.pick(["2.0", "mobile", "https", "http"]) } }
        if rng.chance(0.6) { dict["port"] = rng.pick([53317, 0, -1, 70_000]); dict["download"] = false; dict["announce"] = true }
        var data = (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
        if rng.chance(0.1) { data = data.prefix(rng.int(data.count + 1)) }        // truncated packet
        if rng.chance(0.05) { data = rng.bytes(rng.range(0...2000)) }               // noise on the multicast group
        guard step(index, "localsend packet \(index): \(String(decoding: data.prefix(300), as: UTF8.self))") else { continue }
        let device = LocalSendProtocol.parse(data, from: "192.168.1.\(index % 255)", myFingerprint: "me")
        if let device {
            parsed += 1
            check(device.fingerprint != "me", "own announcement not filtered")
            check(!device.alias.isEmpty, "empty alias accepted")
            expectEq(device.ip, "192.168.1.\(index % 255)", "ip comes from the packet source")
            _ = device.baseURL
            _ = device.symbol
        } else if (dict["fingerprint"] as? String) == "me" { ownFiltered += 1 }
        checks += 1
    }
    // prepare-upload round trip with awkward file names and sizes.
    let me = LocalSendDevice(alias: "Mac \u{1F34E}", version: "2.0", deviceModel: "PepBox", deviceType: "desktop", fingerprint: "fp",
                             port: 53317, protocol: "https", download: false, announce: true)
    for index in 0..<300 {
        let files = (0..<rng.range(0...60)).map { i in
            LocalSendProtocol.FileInfo(id: "file\(i)", fileName: rng.pick(["a.png", "", "../../etc/passwd", "名前.pdf", "a\"b\\c.txt", String(repeating: "n", count: 5000)]),
                                       size: rng.pick([0, 1, Int64.max, Int64(rng.range(0...1 << 40))]), fileType: rng.pick(["image/png", "", "application/octet-stream"]))
        }
        guard step(4_000 + index, "prepare-upload \(files.count) files") else { continue }
        let body = LocalSendProtocol.prepareUploadBody(files: files, sender: me)
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let info = json["info"] as? [String: Any], let map = json["files"] as? [String: [String: Any]] else {
            check(false, "prepare-upload body is not valid JSON (\(files.count) files)"); continue
        }
        expectEq(info["alias"] as? String, me.alias, "prepare-upload alias")
        expectEq(map.count, files.count, "prepare-upload file count")
        for file in files {
            expectEq(map[file.id]?["fileName"] as? String, file.fileName, "prepare-upload name \(short(file.fileName, 30))")
            expectEq((map[file.id]?["size"] as? NSNumber)?.int64Value, file.size, "prepare-upload size \(file.size)")
        }
        // The receiver side decodes the same shape.
        expectEq((try? JSONDecoder().decode(LocalSendDevice.self, from: JSONSerialization.data(withJSONObject: info)))?.fingerprint, "fp", "prepare-upload info decodes as a device")
    }
    note("4000 discovery packets (\(parsed) accepted as devices, \(ownFiltered) own announcements dropped); 300 prepare-upload bodies round-tripped")
}
