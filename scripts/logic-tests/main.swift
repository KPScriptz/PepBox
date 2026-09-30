// Logic tests for dependency-free PepBox code. Run with scripts/logic-tests/run.sh.

import Foundation
import CoreAudio
import AppKit
import ImageIO
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
