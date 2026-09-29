// Logic tests for dependency-free PepBox code. Run with scripts/logic-tests/run.sh.

import Foundation
import CoreAudio
import AppKit

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

print(failures == 0 ? "OK \(checks) checks passed" : "\(failures) of \(checks) checks failed")
exit(failures == 0 ? 0 : 1)
