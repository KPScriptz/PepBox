// Logic tests for dependency-free PepBox code. Run with scripts/logic-tests/run.sh.

import Foundation
import CoreAudio
import AppKit
import ImageIO
import PDFKit
import CoreImage
import UniformTypeIdentifiers

var failures = 0
var checks = 0

func expect<T: Equatable>(_ actual: T, _ expected: T, _ label: String, file: String = #file, line: Int = #line) {
    checks += 1
    if actual != expected {
        failures += 1
        print("FAIL \(label): got \(actual), expected \(expected)  (\((file as NSString).lastPathComponent):\(line))")
    }
}

// MARK: - Quick Search calculator

let math: [(String, String?)] = [
    ("12*4", "48"), ("(3+2)^2", "25"), ("2^3^2", "512"), ("10/4", "2.5"), ("-3+5", "2"),
    ("7%3", "1"), ("1,000*2", "2000"), ("2 × 3", "6"), ("9 ÷ 3", "3"),
    // Malformed or plain input: no answer, and no crash.
    ("1+", nil), ("((2)", nil), ("abc", nil), ("5", nil), ("", nil), ("*", nil), ("2**3", nil), ("1/0", nil)
]
for (input, expected) in math {
    expect(QuickCalculator.evaluate(input).map(QuickCalculator.format), expected, "math \(input)")
}

// MARK: - Unit conversion

let units: [(String, String?)] = [
    ("5 km to mi", "3.1069 mi"), ("70 f to c", "21.1111 c"), ("100 c to f", "212 f"),
    ("2 gb in mb", "2000 mb"), ("3 kg to lb", "6.6139 lb"),
    ("5 km to kg", nil),  // different dimensions
    ("5 parsecs to km", nil), ("hello", nil)
]
for (input, expected) in units {
    expect(QuickUnitConverter.convert(input), expected, "units \(input)")
}

// MARK: - Image metadata stripping

do {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pepbox-strip-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let context = CGContext(data: nil, width: 40, height: 20, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let image = context.makeImage()!
    for type in [UTType.jpeg, .heic, .png] {
        let input = dir.appendingPathComponent("photo").appendingPathExtension(type.preferredFilenameExtension!)
        let destination = CGImageDestinationCreateWithURL(input as CFURL, type.identifier as CFString, 1, nil)!
        let tagged: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 32.78, kCGImagePropertyGPSLatitudeRef: "N"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:09:29 10:00:00", kCGImagePropertyExifLensModel: "Lens"],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFModel: "Camera"],
            kCGImagePropertyOrientation: 6
        ]
        CGImageDestinationAddImage(destination, image, tagged as CFDictionary)
        CGImageDestinationFinalize(destination)

        let name = type.preferredFilenameExtension!
        guard let output = ImageMetadataStripper.strip(input, into: dir),
              let source = CGImageSourceCreateWithURL(output as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            expect(false, true, "strip \(name) produced an image")
            continue
        }
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        expect(properties[kCGImagePropertyGPSDictionary] == nil, true, "strip \(name) GPS")
        expect(exif[kCGImagePropertyExifDateTimeOriginal] == nil && exif[kCGImagePropertyExifLensModel] == nil, true, "strip \(name) EXIF")
        expect(tiff[kCGImagePropertyTIFFModel] == nil, true, "strip \(name) camera model")
        expect((properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue, 6, "strip \(name) keeps orientation")
        expect(output != input, true, "strip \(name) leaves the original")
    }
    expect(ImageMetadataStripper.strip(dir.appendingPathComponent("missing.jpg")) == nil, true, "strip missing file")
}

// MARK: - Quick timers

let timers: [(String, QuickTimerParser.Request?)] = [
    ("timer 5m", .init(seconds: 300, label: nil)),
    ("timer 5", .init(seconds: 300, label: nil)),
    ("timer 1h30m", .init(seconds: 5400, label: nil)),
    ("timer 1h 30m tea", .init(seconds: 5400, label: "tea")),
    ("timer 90 sec", .init(seconds: 90, label: nil)),
    ("timer 4 min pasta water", .init(seconds: 240, label: "pasta water")),
    ("25 min timer", .init(seconds: 1500, label: nil)),
    ("Timer 2.5m", .init(seconds: 150, label: nil)),
    ("timer", nil), ("timer pizza", nil), ("timer 0", nil), ("timer 48h", nil), ("5 km to mi", nil), ("time 5m", nil)
]
for (input, expected) in timers {
    expect(QuickTimerParser.parse(input), expected, "timer \(input)")
}
expect(QuickTimerParser.format(65), "1:05", "timer format m:ss")
expect(QuickTimerParser.format(3725), "1:02:05", "timer format h:mm:ss")
expect(QuickTimerParser.format(0.4), "0:01", "timer format rounds up")

// MARK: - QR codes

for text in ["https://pivotxp.com/booth?id=42", "Hello from PepBox ✨"] {
    let image = QRCodeGenerator.image(for: text)
    let decoded = image.flatMap { $0.cgImage(forProposedRect: nil, context: nil, hints: nil) }.flatMap { cg -> String? in
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil)
        return (detector?.features(in: CIImage(cgImage: cg)).first as? CIQRCodeFeature)?.messageString
    }
    expect(decoded, text, "QR round trip \(text.prefix(12))")
}
expect(QRCodeGenerator.image(for: "") == nil, true, "QR empty text")
expect(QRCodeGenerator.image(for: String(repeating: "x", count: 5000)) == nil, true, "QR too long")

// MARK: - Quick Search commands

let apps: [(String, pid_t)] = [("Safari", 10), ("Slack", 11), ("Spotify", 12), ("Finder", 13)]
func titles(_ query: String) -> [String] { QuickCommand.matches(query, runningApps: apps).map(\.title) }
expect(titles("lock"), ["Lock Screen"], "command lock")
expect(titles("slee"), ["Sleep"], "command sleep prefix")
expect(titles("restart"), ["Restart…"], "command restart")
expect(titles("shut"), ["Shut Down…"], "command shut down")
expect(titles("eject"), ["Eject All Disks"], "command eject")
expect(titles("quit s"), ["Quit Safari", "Quit Slack", "Quit Spotify"], "command quit prefix")
expect(titles("quit spo"), ["Quit Spotify"], "command quit narrow")
expect(titles("quit "), [], "command quit without name")
expect(titles("wi-fi"), ["Wi-Fi Settings"], "settings wifi")
expect(titles("bluetooth settings"), ["Bluetooth Settings"], "settings suffix")
expect(titles("security"), ["Privacy & Security Settings"], "settings second word")
expect(titles("ocr"), ["Copy Text from Screen"], "command ocr")
expect(titles("grab"), ["Copy Text from Screen"], "command grab text")
expect(titles("x"), [], "command too short")
expect(titles("zzzz"), [], "command no match")

// MARK: - Agents log parsing

do {
    func json(_ object: Any) -> String { String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self) }
    let prompt = json(["type": "user", "cwd": "/Users/me/PepBox", "timestamp": "2026-09-29T10:00:00.000Z", "message": ["role": "user", "content": "fix the bug"]])
    let edit = json(["type": "assistant", "cwd": "/Users/me/PepBox", "message": ["role": "assistant", "stop_reason": "tool_use",
        "content": [["type": "tool_use", "name": "Edit", "input": ["file_path": "/Users/me/PepBox/App.swift"]]]]])
    let result = json(["type": "user", "message": ["role": "user", "content": [["type": "tool_result", "content": "ok"]]]])
    let bash = json(["type": "assistant", "message": ["role": "assistant", "content": [["type": "tool_use", "name": "Bash", "input": ["command": "xcodebuild -scheme X", "description": "Build the app"]]]]])
    let sidechain = json(["type": "assistant", "isSidechain": true, "message": ["role": "assistant", "content": [["type": "tool_use", "name": "Read", "input": ["file_path": "/x/Secret.swift"]]]]])
    let done = json(["type": "assistant", "message": ["role": "assistant", "stop_reason": "end_turn", "content": [["type": "text", "text": "All fixed."]]]])

    let running = AgentTranscriptParser.parseClaude([prompt, edit, result, bash, sidechain])
    expect(running?.project, "PepBox", "agents project from cwd")
    expect(running?.state, .tool("Build the app"), "agents current tool uses Bash description")
    expect(running?.tools, ["Edit App.swift", "Build the app"], "agents tool list, sidechain skipped")
    expect(running?.toolCount, 2, "agents tool count")
    expect(running?.editCount, 1, "agents edit count")
    expect(running?.promptStart != nil, true, "agents prompt time")
    expect(AgentTranscriptParser.parseClaude([prompt, edit, result, done])?.state, .done, "agents end_turn is done")
    expect(AgentTranscriptParser.parseClaude([prompt, edit, result, done, prompt])?.toolCount, 0, "agents new prompt resets")
    expect(AgentTranscriptParser.parseClaude(["not json", ""]) == nil, true, "agents garbage")
    expect(AgentTranscriptParser.toolLabel(name: "mcp__github__create_issue", input: [:]), "create issue", "agents MCP label")

    let codex = [
        json(["type": "session_meta", "payload": ["cwd": "/Users/me/site"]]),
        json(["type": "event_msg", "timestamp": "2026-09-29T10:00:00.000Z", "payload": ["type": "user_message", "message": "go"]]),
        json(["type": "response_item", "payload": ["type": "function_call", "name": "exec_command", "arguments": "{\"cmd\":\"npm test\"}"]]),
        json(["type": "response_item", "payload": ["type": "custom_tool_call", "name": "apply_patch", "input": "*** Begin Patch\n*** Update File: /Users/me/site/index.html\n"]])
    ]
    let codexSnapshot = AgentTranscriptParser.parseCodex(codex)
    expect(codexSnapshot?.project, "site", "codex project from session_meta")
    expect(codexSnapshot?.tools, ["Run npm", "Edit index.html"], "codex tool labels")
    expect(codexSnapshot?.editCount, 1, "codex edits")
    expect(AgentTranscriptParser.parseCodex(codex + [json(["type": "event_msg", "payload": ["type": "task_complete"]])])?.state, .done, "codex done")
}

// MARK: - LocalSend protocol

do {
    let pixel = #"{"alias":"Pixel","version":"2.0","deviceModel":"Pixel 9","deviceType":"mobile","fingerprint":"abc","port":53317,"protocol":"https","download":false,"announce":true}"#
    let device = LocalSendProtocol.parse(Data(pixel.utf8), from: "192.168.1.20", myFingerprint: "me")
    expect(device?.alias, "Pixel", "localsend alias")
    expect(device?.symbol, "iphone", "localsend mobile symbol")
    expect(device?.baseURL?.absoluteString, "https://192.168.1.20:53317", "localsend base URL")
    expect(LocalSendProtocol.parse(Data(pixel.utf8), from: "x", myFingerprint: "abc") == nil, true, "localsend ignores own announce")
    expect(LocalSendProtocol.parse(Data("junk".utf8), from: "x", myFingerprint: "me") == nil, true, "localsend junk")
    let minimal = LocalSendProtocol.parse(Data(#"{"alias":"Old","fingerprint":"f"}"#.utf8), from: "10.0.0.2", myFingerprint: "me")
    expect(minimal?.baseURL?.absoluteString, "https://10.0.0.2:53317", "localsend defaults port/protocol")

    let me = LocalSendDevice(alias: "Mac", version: "2.0", deviceModel: "PepBox", deviceType: "desktop", fingerprint: "fp",
                             port: 53317, protocol: "https", download: false, announce: true)
    let body = LocalSendProtocol.prepareUploadBody(files: [.init(id: "file0", fileName: "a.png", size: 12, fileType: "image/png")], sender: me)
    let json = try! JSONSerialization.jsonObject(with: body) as! [String: Any]
    let info = json["info"] as! [String: Any]
    let files = json["files"] as! [String: [String: Any]]
    expect(info["alias"] as? String, "Mac", "localsend prepare info alias")
    expect(info["announce"] == nil, true, "localsend prepare omits announce")
    expect(files["file0"]?["fileName"] as? String, "a.png", "localsend prepare file name")
    expect((files["file0"]?["size"] as? NSNumber)?.int64Value, 12, "localsend prepare size")
    let announcement = try! JSONSerialization.jsonObject(with: LocalSendProtocol.announcement(me)) as! [String: Any]
    expect(announcement["announce"] as? Bool, true, "localsend announce flag")
    expect(announcement["ip"] == nil, true, "localsend announce has no ip field")
}

// MARK: - LocalSend HTTP reader

do {
    func run(_ raw: String, splitEvery size: Int) -> (head: HTTPRequestHead?, body: Data, ended: Bool, malformed: Bool) {
        let reader = HTTPRequestReader()
        let bytes = Data(raw.utf8)
        var head: HTTPRequestHead?, body = Data(), ended = false, malformed = false
        var index = 0
        while index < bytes.count {
            let piece = bytes[index..<min(index + size, bytes.count)]
            for event in reader.feed(Data(piece)) {
                switch event {
                case .head(let h): head = h
                case .body(let d): body.append(d)
                case .end: ended = true
                case .malformed: malformed = true
                }
            }
            index += size
        }
        return (head, body, ended, malformed)
    }
    let plain = "POST /api/localsend/v2/upload?sessionId=s1&fileId=f1&token=t%201 HTTP/1.1\r\nHost: x\r\nContent-Length: 11\r\n\r\nhello world"
    for size in [1, 3, 7, 1000] {
        let result = run(plain, splitEvery: size)
        expect(result.head?.path, "/api/localsend/v2/upload", "http path (split \(size))")
        expect(result.head?.query["token"], "t 1", "http query decoded (split \(size))")
        expect(String(decoding: result.body, as: UTF8.self), "hello world", "http body (split \(size))")
        expect(result.ended, true, "http end (split \(size))")
    }
    let chunked = "POST /u HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n6;ext=1\r\n world\r\n0\r\n\r\n"
    for size in [1, 2, 5, 1000] {
        let result = run(chunked, splitEvery: size)
        expect(String(decoding: result.body, as: UTF8.self), "hello world", "http chunked body (split \(size))")
        expect(result.ended, true, "http chunked end (split \(size))")
    }
    expect(run("GET /api/localsend/v2/info HTTP/1.1\r\n\r\n", splitEvery: 4).ended, true, "http no body ends")
    expect(run("POST /u HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\nzz\r\n", splitEvery: 100).malformed, true, "http bad chunk size")
    expect(run("garbage\r\n\r\n", splitEvery: 100).malformed, true, "http bad request line")
    let response = String(decoding: HTTPRequestReader.response(status: 403), as: UTF8.self)
    expect(response.hasPrefix("HTTP/1.1 403 Forbidden\r\nContent-Length: 0"), true, "http response line")
}

// MARK: - Quick Search tools

do {
    // 2026-09-30 14:00:00 UTC, a Wednesday.
    let now = Date(timeIntervalSince1970: 1790776800)
    let chicago = TimeZone(identifier: "America/Chicago")!
    var counter: UInt64 = 0
    let fakeRandom: () -> UInt64 = { counter &+= 7919; return counter }
    func titles(_ q: String) -> [String] { QuickTools.answers(for: q, now: now, timeZone: chicago, random: fakeRandom).map(\.title) }
    func first(_ q: String) -> String? { titles(q).first }

    // Colors
    expect(titles("#ff8800"), ["#FF8800", "rgb(255, 136, 0)", "hsl(32, 100%, 50%)"], "color hex")
    expect(first("#f80"), "#FF8800", "color short hex")
    expect(first("rgb(0, 128, 255)"), "#0080FF", "color rgb")
    expect(first("ff8800"), "#FF8800", "color bare mixed hex")
    expect(titles("facade"), [], "color ignores words")
    expect(titles("add"), [], "color ignores short words")
    expect(titles("123456").contains("#123456"), false, "color ignores plain numbers")

    // Time zones
    expect(first("time in tokyo"), "11:00 PM, Wed in Tokyo", "tz time in city")
    expect(first("3pm est in pst"), "12:00 PM, Wed in PST", "tz convert abbreviations")
    expect(first("15:30 london to new york"), "10:30 AM, Wed in New York", "tz convert cities 24h")
    expect(titles("time in narnia"), [], "tz unknown")

    // Dates
    expect(first("days until dec 25"), "86 days", "days until month day")
    expect(first("days until christmas"), "86 days", "days until named")
    expect(first("days until 2026-09-30"), "Today", "days until today")
    expect(first("days until 2026-09-01"), "29 days ago", "days until past")
    expect(first("today + 30 days"), "Friday, October 30, 2026", "date plus days")
    expect(first("in 2 weeks"), "Wednesday, October 14, 2026", "date in weeks")
    expect(first("3 months ago"), "Tuesday, June 30, 2026", "date ago")
    expect(titles("30 days"), [], "date needs a direction")

    // Bases
    expect(titles("0xff"), ["255", "0b11111111"], "base hex in")
    expect(titles("255 in hex"), ["0xFF"], "base to hex")
    expect(titles("10 to binary"), ["0b1010"], "base to binary")
    expect(titles("0b1010"), ["10", "0xA"], "base binary in")

    // Percent
    expect(first("15% of 80"), "12", "percent of")
    expect(titles("tip 20% of $64.50"), ["12.90", "Total 77.40"], "percent tip")
    expect(first("30 is what % of 120"), "25%", "percent what")
    expect(first("80 - 15%"), "68", "percent change")

    // Timestamps
    expect(first("timestamp"), "1790776800", "unix now")
    expect(first("1790776800"), "Wed, Sep 30, 2026 at 9:00:00 AM CDT", "unix to date")
    expect(first("1790776800000"), "Wed, Sep 30, 2026 at 9:00:00 AM CDT", "unix ms to date")
    expect(titles("1234567890123456"), [], "unix ignores long numbers")

    // Encodings
    expect(first("base64 hello"), "aGVsbG8=", "base64 encode")
    expect(first("base64 decode aGVsbG8"), "hello", "base64 decode unpadded")
    expect(first("url encode a b&c"), "a%20b%26c", "url encode")
    expect(first("url decode a%20b"), "a b", "url decode")

    // Generators
    let uuid = first("uuid") ?? ""
    expect(UUID(uuidString: uuid) != nil && uuid.dropFirst(14).first == "4", true, "uuid v4 format")
    let password = first("password 24") ?? ""
    expect(password.count, 24, "password length")
    expect(password.contains(where: \.isUppercase) && password.contains(where: \.isLowercase)
           && password.contains(where: \.isNumber) && password.contains(where: { "!@#$%^&*-_=+?".contains($0) }), true, "password has every kind")
    expect(first("password 3").map(\.count), 8, "password minimum length")
    expect(QuickTools.answers(for: "lorem 2").first?.copy.components(separatedBy: "\n\n").count, 2, "lorem paragraphs")
    expect(first("roll 2d6")?.hasPrefix("🎲 "), true, "roll dice")
    expect(titles("roll d1"), [], "roll needs 2+ sides")
    expect(["🪙 Heads", "🪙 Tails"].contains(first("flip") ?? ""), true, "coin flip")
    expect(titles("hello world"), [], "tools stay quiet on plain text")

    expect(QuickTools.awakeRequest("awake"), .indefinite, "awake default")
    expect(QuickTools.awakeRequest("awake 1h"), .minutes(60), "awake hours")
    expect(QuickTools.awakeRequest("awake 90 min"), .minutes(90), "awake minutes spaced")
    expect(QuickTools.awakeRequest("caffeinate 30"), .minutes(30), "awake bare minutes")
    expect(QuickTools.awakeRequest("stay awake 2 hours"), .minutes(120), "stay awake")
    expect(QuickTools.awakeRequest("awake off"), .off, "awake off")
    expect(QuickTools.awakeRequest("awake 48h"), nil, "awake too long")
    expect(QuickTools.awakeRequest("awakening"), nil, "awake needs the word")
    expect(QuickTools.reminder("remind stretch in 20m"), .init(seconds: 1200, label: "stretch"), "remind simple")
    expect(QuickTools.reminder("remind me to call mom in 1h 30m"), .init(seconds: 5400, label: "call mom"), "remind me to")
    expect(QuickTools.reminder("remind me to check in with sam in 5 min"), .init(seconds: 300, label: "check in with sam"), "remind uses last in")
    expect(QuickTools.reminder("remind in 5m"), nil, "remind needs a label")
    expect(QuickTools.reminder("remind stretch"), nil, "remind needs a time")
    expect(QuickTools.argument("Note Buy milk ", after: ["note"]), "Buy milk", "argument keeps case")
    expect(QuickTools.argument("notes", after: ["note"]), nil, "argument needs the word")
    expect(QuickTools.argument("todo  ", after: ["todo"]), nil, "argument needs text")
    expect(QuickTools.pmsetRemaining(" -InternalBattery-0 (id=7602275)\t33%; charging; 2:35 remaining present: true"), "2:35", "pmset remaining")
    expect(QuickTools.pmsetRemaining("33%; charging; (no estimate) present: true"), nil, "pmset no estimate")
    expect(QuickTools.portQuery("port 3000"), 3000, "port query")
    expect(QuickTools.portQuery(":8080"), 8080, "port colon")
    expect(QuickTools.portQuery("port 99999"), nil, "port range")
    let lsof = QuickTools.parseLsof("p123\ncnode\nn*:3000\nn[::]:3000\np456\ncPython\nn127.0.0.1:3000\n")
    expect(lsof.map(\.pid), [123, 456], "lsof pids")
    expect(lsof.map(\.command), ["node", "Python"], "lsof commands")
}

// MARK: - File tools and text transforms

do {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pepbox-filetools-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    // A 400×200 JPEG with orientation 6 (rotated): resizing to 100 must bake the rotation in → 50×100.
    let context = CGContext(data: nil, width: 400, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(red: 0, green: 0.5, blue: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
    let photo = dir.appendingPathComponent("photo.jpg")
    let dest = CGImageDestinationCreateWithURL(photo as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, context.makeImage()!, [kCGImagePropertyOrientation: 6] as CFDictionary)
    CGImageDestinationFinalize(dest)
    let resized = FileTools.resizeImage(photo, maxDimension: 100, into: dir)
    let props = resized.flatMap { CGImageSourceCreateWithURL($0 as CFURL, nil) }.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
    expect(props?[kCGImagePropertyPixelWidth] as? Int, 50, "resize width (rotation applied)")
    expect(props?[kCGImagePropertyPixelHeight] as? Int, 100, "resize height")
    expect(resized?.pathExtension, "jpg", "resize keeps format")

    // Images → PDF, then merge two PDFs.
    let png = dir.appendingPathComponent("a.png")
    try? NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])?.write(to: png)
    let single = FileTools.imagesToPDF([photo, png], into: dir)
    expect(single.flatMap { PDFDocument(url: $0) }?.pageCount, 2, "images to PDF pages")
    let merged = single.flatMap { FileTools.mergePDFs([$0, $0], into: dir) }
    expect(merged.flatMap { PDFDocument(url: $0) }?.pageCount, 4, "merge PDFs pages")
    expect(FileTools.mergePDFs([png], into: dir) == nil, true, "merge rejects non-PDF")

    // Checksum
    let text = dir.appendingPathComponent("hello.txt")
    try? Data("hello".utf8).write(to: text)
    expect(FileTools.sha256(text), "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824", "sha256")

    expect(FileTools.sequentialNames(base: "Photo", count: 3), ["Photo 1", "Photo 2", "Photo 3"], "sequential names")
    expect(FileTools.sequentialNames(base: "Shot", count: 12).last, "Shot 12", "sequential last")
    expect(FileTools.sequentialNames(base: "Shot", count: 12).first, "Shot 01", "sequential zero pad")
    expect(FileTools.dataURI(png)?.hasPrefix("data:image/png;base64,iVBOR"), true, "data URI png")
    expect(FileTools.textContents(text), "hello", "text contents")
    expect(FileTools.textContents(photo) == nil, true, "text contents rejects binary")

    // Text transforms
    expect(TextTransform.titleCase.apply("hello big world"), "Hello Big World", "title case")
    expect(TextTransform.sentenceCase.apply("HELLO THERE. how are you? fine"), "Hello there. How are you? Fine", "sentence case")
    expect(TextTransform.trim.apply("  a  \n   b \n\n"), "a\nb", "trim lines")
    expect(TextTransform.singleLine.apply("one\n two\n\nthree"), "one two three", "single line")
    expect(TextTransform.sortLines.apply("b\na10\na2"), "a2\na10\nb", "sort lines naturally")
    expect(TextTransform.uniqueLines.apply("x\ny\nx\nz\ny"), "x\ny\nz", "unique lines")
    expect(TextTransform.prettyJSON.apply(#"{"b":1,"a":[1,2]}"#), "{\n  \"a\" : [\n    1,\n    2\n  ],\n  \"b\" : 1\n}", "pretty JSON")
    expect(TextTransform.prettyJSON.apply("not json"), nil, "pretty JSON rejects text")
    expect(TextTransform.slug.apply("Héllo, World! 2026"), "hello-world-2026", "slug")
}

// MARK: - Currency conversion

let rates: [String: Double] = ["USD": 1, "EUR": 0.5, "GBP": 0.25, "JPY": 150, "CAD": 1.25]
let currency: [(String, String?)] = [
    ("100 usd to eur", "50.00 EUR"), ("$20 in gbp", "5.00 GBP"), ("50€ to $", "100.00 USD"),
    ("1,000 jpy to usd", "6.67 USD"), ("10 cad to eur", "4.00 EUR"), ("5 euros to yen", "1,500.00 JPY"),
    ("$5 usd to eur", nil),  // two source currencies
    ("100 xyz to eur", nil), ("100 usd to usd", nil), ("5 km to mi", nil)
]
for (input, expected) in currency {
    expect(QuickCurrencyConverter.convert(input, rates: rates), expected, "currency \(input)")
}
expect(QuickCurrencyConverter.convert("100 usd to eur", rates: [:]), nil, "currency without rates")

// MARK: - Smooth Scroll easing: every glide ends and delivers its full distance

for lines in [1, 3, -2, 10, -25] {
    var pending = Double(lines) * ScrollEasing.pixelsPerLine
    var total: Int32 = 0
    var frames = 0
    while abs(pending) >= 0.5 && frames < 10_000 {
        let step = ScrollEasing.nextStep(remaining: pending, easing: 0.2)
        pending -= Double(step)
        total += step
        frames += 1
    }
    expect(total, Int32(Double(lines) * ScrollEasing.pixelsPerLine), "scroll total \(lines) lines")
    expect(frames < 60, true, "scroll \(lines) lines ends quickly (\(frames) frames)")
}

// MARK: - App Volume sample copy

func makeList(_ buffers: [(channels: Int, samples: [Float])]) -> UnsafeMutableAudioBufferListPointer {
    let list = AudioBufferList.allocate(maximumBuffers: buffers.count)
    for (index, buffer) in buffers.enumerated() {
        let data = UnsafeMutablePointer<Float>.allocate(capacity: buffer.samples.count)
        data.initialize(from: buffer.samples, count: buffer.samples.count)
        list[index] = AudioBuffer(mNumberChannels: UInt32(buffer.channels),
                                  mDataByteSize: UInt32(buffer.samples.count * MemoryLayout<Float>.size), mData: data)
    }
    return list
}

func samples(_ list: UnsafeMutableAudioBufferListPointer) -> [[Float]] {
    list.map { Array(UnsafeBufferPointer(start: $0.mData!.assumingMemoryBound(to: Float.self), count: Int($0.mDataByteSize) / 4)) }
}

func copyCase(_ input: [(Int, [Float])], _ output: [(Int, [Float])], gain: Float) -> [[Float]] {
    let inList = makeList(input.map { (channels: $0.0, samples: $0.1) })
    let outList = makeList(output.map { (channels: $0.0, samples: $0.1) })
    AudioSampleCopier.copy(UnsafePointer(inList.unsafeMutablePointer), to: outList.unsafeMutablePointer, gain: gain)
    return samples(outList)
}

expect(copyCase([(2, [0.1, 0.3, 0.2, 0.4])], [(2, [9, 9, 9, 9])], gain: 2), [[0.2, 0.6, 0.4, 0.8]], "copy interleaved stereo with gain")
expect(copyCase([(1, [0.2, 0.4]), (1, [0.6, 0.8])], [(2, [9, 9, 9, 9])], gain: 0.5), [[0.1, 0.3, 0.2, 0.4]], "copy split -> interleaved")
expect(copyCase([(1, [0.9, -0.9])], [(1, [9, 9]), (1, [9, 9])], gain: 1.5), [[1, -1], [1, -1]], "copy mono -> two channels, clipped")
expect(copyCase([(2, [0.5, 0.5])], [(2, [9, 9, 9, 9])], gain: 1), [[0.5, 0.5, 0, 0]], "copy pads missing frames with silence")
expect(copyCase([(2, [])], [(2, [9, 9])], gain: 1), [[0, 0]], "copy with an empty input buffer writes silence")

// MARK: - Clipboard shortcut default and migration (SavedShortcut)

let defaults = UserDefaults.standard
defaults.removeObject(forKey: "clipboardShortcut")
expect(SavedShortcut.storedClipboardShortcut(), SavedShortcut.clipboardDefault, "no saved shortcut -> Option+Space")
expect(SavedShortcut.clipboardDefault.description, "⌥Space", "default shortcut description")

let legacy = SavedShortcut(keyCode: 49, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue)
defaults.set(try! JSONEncoder().encode(legacy), forKey: "clipboardShortcut")
expect(SavedShortcut.storedClipboardShortcut(), SavedShortcut.clipboardDefault, "saved Cmd+Shift+Space migrates to Option+Space")
expect(defaults.data(forKey: "clipboardShortcut") == nil, true, "migration clears the saved legacy shortcut")

let custom = SavedShortcut(keyCode: 9, modifiers: NSEvent.ModifierFlags([.control, .command]).rawValue)
defaults.set(try! JSONEncoder().encode(custom), forKey: "clipboardShortcut")
expect(SavedShortcut.storedClipboardShortcut(), custom, "a custom shortcut is kept")
defaults.removeObject(forKey: "clipboardShortcut")

// MARK: - Pomodoro cycle

for key in ["pomodoro_focusMinutes", "pomodoro_shortBreakMinutes", "pomodoro_longBreakMinutes"] {
    defaults.removeObject(forKey: key)
}
let pomodoro = PomodoroManager.shared
pomodoro.reset()
expect(pomodoro.phase, .focus, "starts in focus")
expect(pomodoro.formattedRemaining, "25:00", "default focus is 25 minutes")
var phases: [PomodoroManager.Phase] = []
for _ in 0..<8 {
    pomodoro.skip()
    phases.append(pomodoro.phase)
}
expect(phases, [.shortBreak, .focus, .shortBreak, .focus, .shortBreak, .focus, .longBreak, .focus],
       "long break after every 4th focus session")
expect(pomodoro.isRunning, false, "skipping leaves the timer paused")

pomodoro.select(.shortBreak)
expect(pomodoro.formattedRemaining, "05:00", "default break is 5 minutes")
pomodoro.shortBreakMinutes = 7
expect(pomodoro.formattedRemaining, "07:00", "changing the current phase's length applies at once")
expect(defaults.integer(forKey: "pomodoro_shortBreakMinutes"), 7, "durations are saved")
pomodoro.start()
expect(pomodoro.isRunning, true, "start runs the timer")
pomodoro.pause()
expect(pomodoro.isRunning, false, "pause stops it")
pomodoro.reset()
expect(pomodoro.phase, .focus, "reset returns to focus")
expect(pomodoro.completedFocusSessions, 0, "reset clears finished sessions")
for key in ["pomodoro_focusMinutes", "pomodoro_shortBreakMinutes", "pomodoro_longBreakMinutes"] {
    defaults.removeObject(forKey: key)
}

// MARK: - Emoji catalog and recents

expect(EmojiCatalog.all.count > 1000, true, "emoji catalog has 1000+ entries (\(EmojiCatalog.all.count))")
expect(EmojiCatalog.all.contains { $0.emoji == "😀" && $0.name == "grinning face" }, true, "grinning face is named")
expect(EmojiCatalog.all.contains { $0.name.contains("heart") }, true, "search finds hearts")
expect(EmojiCatalog.all.contains { $0.emoji.unicodeScalars.first!.value == 0x1F3FB }, false, "skin-tone modifiers are left out")
defaults.removeObject(forKey: "emojiPicker_recents")
for emoji in ["😀", "🎉", "😀"] { EmojiCatalog.noteUsed(emoji) }
expect(EmojiCatalog.recents, ["😀", "🎉"], "recents: newest first, no duplicates")
for index in 0..<20 { EmojiCatalog.noteUsed(EmojiCatalog.all[index].emoji) }
expect(EmojiCatalog.recents.count, 16, "recents are capped at 16")
defaults.removeObject(forKey: "emojiPicker_recents")

// MARK: - Obsidian vault detection and capture

let temp = FileManager.default.temporaryDirectory.appendingPathComponent("pepbox-obsidian-test-\(UUID().uuidString)")
let openVault = temp.appendingPathComponent("Open"), newerVault = temp.appendingPathComponent("Newer")
try! FileManager.default.createDirectory(at: openVault, withIntermediateDirectories: true)
try! FileManager.default.createDirectory(at: newerVault, withIntermediateDirectories: true)
let config = temp.appendingPathComponent("obsidian.json")
try! """
{"vaults":{"a":{"path":"\(newerVault.path)","ts":1790000000000},"b":{"path":"\(openVault.path)","ts":1700000000000,"open":true}}}
""".write(to: config, atomically: true, encoding: .utf8)
expect(ObsidianManager.detectVault(configURL: config)?.lastPathComponent, "Open", "open vault wins over a more recent one")
try! #"{"vaults":{"a":{"path":"/x/Old","ts":1},"b":{"path":"/x/New","ts":2}}}"#.write(to: config, atomically: true, encoding: .utf8)
expect(ObsidianManager.detectVault(configURL: config)?.path, "/x/New", "otherwise the most recent vault")
expect(ObsidianManager.detectVault(configURL: temp.appendingPathComponent("missing.json")) == nil, true, "no config -> no vault")
try? FileManager.default.removeItem(at: temp)

// MARK: - Synced lyrics (LRC)

let lrc = SyncedLyrics(lrc: """
[ar:Someone]
[00:05.00] First line
[00:10.50]
[00:12.20][01:02.00] Chorus
[1:15.5] Late line
not a lyric line
""")
expect(lrc.lines.count, 5, "LRC: metadata and untimed lines skipped, multi-stamp lines duplicated")
expect(lrc.line(at: 1), nil, "LRC: nothing before the first line")
expect(lrc.line(at: 5), "First line", "LRC: line starts exactly at its time")
expect(lrc.line(at: 9.9), "First line", "LRC: line holds until the next")
expect(lrc.line(at: 11), nil, "LRC: empty line = instrumental gap")
expect(lrc.line(at: 30), "Chorus", "LRC: first chorus")
expect(lrc.line(at: 62.5), "Chorus", "LRC: repeated chorus timestamp")
expect(lrc.line(at: 80), "Late line", "LRC: m:ss.s timestamps")

print(failures == 0 ? "OK \(checks) checks passed" : "\(failures) of \(checks) checks failed")
exit(failures == 0 ? 0 : 1)
