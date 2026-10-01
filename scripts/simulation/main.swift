// PepBox long-run usage simulation. Run with scripts/simulation/run.sh.
//
// Usage: pepbox-simulation <scenario> [start-case]
// Each scenario prints FAIL/NOTE lines and one RESULT line; run.sh runs every scenario in
// its own process so a crash (Swift trap) or hang is reported with the exact input and the
// scenario resumes after it.

import Foundation
import CryptoKit

// MARK: - Performance

func scenarioPerf(start: Int) {
    let now = Date(timeIntervalSince1970: 1_790_776_800)
    let zone = TimeZone(identifier: "America/Chicago")!
    // 1) Quick Search per keystroke: what QuickSearch.swift runs for each character typed.
    let queries = (0..<10_000).map { index -> String in
        let full = quickSearchInput(index + 1_000_000)
        return String(full.prefix(1 + index % max(1, min(full.count, 40))))   // a prefix, like typing
    }.filter { $0.count < 200 }
    var answersMs = 0.0, keystrokeMs = 0.0
    for (index, query) in queries.enumerated() {
        Crumb.set(index, query)
        answersMs += timed { _ = QuickTools.answers(for: query, now: now, timeZone: zone) }
        keystrokeMs += timed {
            _ = QuickTools.answers(for: query, now: now, timeZone: zone) + QuickTools.devTools(query, now: now)
            _ = QuickCalculator.evaluate(query); _ = QuickUnitConverter.convert(query)
            _ = QuickCurrencyConverter.convert(query, rates: ["USD": 1, "EUR": 0.9]); _ = QuickTimerParser.parse(query)
            _ = QuickCommand.matches(query); _ = QuickTools.typedURL(query); _ = QuickTools.mailto(query); _ = QuickTools.reminder(query)
        }
    }
    let answersAvg = answersMs / Double(queries.count), keystrokeAvg = keystrokeMs / Double(queries.count)
    var eventMs = 0.0
    for query in queries.prefix(300) { eventMs += timed { _ = QuickTools.eventRequest("event " + query) } }
    let eventAvg = eventMs / 300
    check(answersAvg < 2, String(format: "QuickTools.answers averages %.3f ms per keystroke (budget 2 ms)", answersAvg))
    print(String(format: "PERF answers %.3f ms avg over %d queries; full keystroke bundle %.3f ms; eventRequest %.3f ms", answersAvg, queries.count, keystrokeAvg, eventAvg))

    // 2) ClipboardStack.plan with 500 items: realistic sizes, and 500 large pastes.
    var rng = RNG(0x9E7F)
    func entries(textSize: ClosedRange<Int>) -> [ClipboardStack.Entry] {
        (0..<500).map { _ in
            switch rng.int(10) {
            case 0: return .file("/Users/kp/f\(rng.int(100)).pdf")
            case 1: return .image(rng.uuid())
            default: return .text(String(repeating: "x", count: rng.range(textSize)))
            }
        }
    }
    let small = entries(textSize: 1...200), large = entries(textSize: 5_000...20_000), allText = (0..<500).map { _ in ClipboardStack.Entry.text(String(repeating: "y", count: 10_000)) }
    var planSmall = 0.0, planLarge = 0.0, planAllText = 0.0
    for _ in 0..<20 {
        planSmall += timed { _ = ClipboardStack.plan(small, separator: .newline) }
        planLarge += timed { _ = ClipboardStack.plan(large, separator: .newline) }
        planAllText += timed { _ = ClipboardStack.plan(allText, separator: .comma) }
    }
    planSmall /= 20; planLarge /= 20; planAllText /= 20
    var ids = (0..<500).map { _ in rng.uuid() }
    let dates = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, Date(timeIntervalSince1970: Double($0))) })
    ids.shuffle(using: &rng)
    let reconcileMs = timed { for _ in 0..<20 { _ = ClipboardStack.reconcile(order: Array(ids.prefix(250)), selected: Set(ids), dates: dates) } } / 20
    check(planSmall < 5, String(format: "plan(500 short items) %.2f ms (budget 5 ms)", planSmall))
    check(planLarge < 5, String(format: "plan(500 pastes of 5–20 KB) %.2f ms (budget 5 ms)", planLarge))
    check(planAllText < 5, String(format: "plan(500 × 10 KB text) %.2f ms (budget 5 ms)", planAllText))
    print(String(format: "PERF plan 500 short %.3f ms; 500 large %.2f ms; 500×10KB text %.2f ms; reconcile 500 %.3f ms", planSmall, planLarge, planAllText, reconcileMs))

    // 3) HTTP reader: 50 MB upload as Content-Length and as chunked, in 256 KB reads.
    var bodyRNG = RNG(5)
    let body = bodyRNG.bytes(50 * 1_048_576)
    let plainRaw = Data("POST /api/localsend/v2/upload HTTP/1.1\r\nContent-Length: \(body.count)\r\n\r\n".utf8) + body
    var chunkedRaw = Data("POST /u HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n".utf8)
    var offset = 0
    while offset < body.count {
        let size = min(16_384, body.count - offset)
        chunkedRaw += Data((String(size, radix: 16) + "\r\n").utf8) + body[offset..<(offset + size)] + Data("\r\n".utf8)
        offset += size
    }
    chunkedRaw += Data("0\r\n\r\n".utf8)
    var kbChunks = Data("POST /u HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n".utf8)
    for start in stride(from: 0, to: 20 * 1_048_576, by: 1024) { kbChunks += Data("400\r\n".utf8) + body[start..<(start + 1024)] + Data("\r\n".utf8) }
    kbChunks += Data("0\r\n\r\n".utf8)
    var tinyChunks = Data("POST /u HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n".utf8)
    for byte in body.prefix(512 * 1024) { tinyChunks += Data([0x31, 0x0D, 0x0A, byte, 0x0D, 0x0A]) }   // 512 KB in 1-byte chunks
    tinyChunks += Data("0\r\n\r\n".utf8)
    Crumb.set(20_000, "perf http")
    var plainRun = ReaderRun(), chunkedRun = ReaderRun(), tinyRun = ReaderRun()
    let plainMs = timed { plainRun = feedReader(plainRaw, pieceSizes: [262_144]) }
    Crumb.set(20_001, "perf http chunked")
    let chunkedMs = timed { chunkedRun = feedReader(chunkedRaw, pieceSizes: [262_144]) }
    Crumb.set(20_002, "perf http 1 KB chunks")
    var kbRun = ReaderRun()
    let kbMs = timed { kbRun = feedReader(kbChunks, pieceSizes: [262_144]) }
    let kbRate = 20 / (kbMs / 1000)
    check(kbRun.body == body.prefix(20 * 1_048_576), "perf HTTP 1 KB chunk body round-trips")
    check(kbRate > 50, String(format: "HTTP reader 1 KB chunks %.0f MB/s (budget >50)", kbRate))
    Crumb.set(20_003, "perf http 1-byte chunks")
    let tinyMs = timed { tinyRun = feedReader(tinyChunks, pieceSizes: [262_144]) }
    check(plainRun.body == body && chunkedRun.body == body && tinyRun.body == body.prefix(512 * 1024), "perf HTTP bodies round-trip")
    let plainRate = 50 / (plainMs / 1000), chunkedRate = 50 / (chunkedMs / 1000), tinyRate = 0.5 / (tinyMs / 1000)
    check(plainRate > 50, String(format: "HTTP reader Content-Length %.0f MB/s (budget >50)", plainRate))
    check(chunkedRate > 50, String(format: "HTTP reader chunked %.0f MB/s (budget >50)", chunkedRate))
    check(tinyRate > 0.5, String(format: "HTTP reader 1-byte chunks %.2f MB/s (budget >0.5; was 0.01 when every chunk shifted the buffer)", tinyRate))
    print(String(format: "PERF http content-length %.0f MB/s; chunked(16KB) %.0f MB/s; chunked(1KB) %.0f MB/s; 1-byte chunks %.2f MB/s", plainRate, chunkedRate, kbRate, tinyRate))

    // 4) Snippet keystrokes with a big snippet list (the controller passes the whole list each key).
    let many = (0..<200).map { Snippet(trigger: ";s\($0)", text: "t") }
    var engine = SnippetEngine()
    let keys = Array("the quick brown fox ;s1 jumps;s99 over\u{7F}r ")
    let keyMs = timed { for i in 0..<200_000 { _ = engine.type(String(keys[i % keys.count]), snippets: many) } }
    print(String(format: "PERF snippet keystroke with 200 snippets: %.2f µs", keyMs * 1000 / 200_000))
    check(keyMs / 200_000 < 0.5, "snippet keystroke over 0.5 ms")
    measureAgentPoll()
}

// MARK: - Agents monitor poll cost (measured alone; the monitor repeats it every 1.5 s per active log)

func measureAgentPoll() {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("pepbox-sim-poll-\(getpid()).jsonl")
    defer { try? FileManager.default.removeItem(at: url) }
    var text = ""
    for i in 0..<30_000 {
        text += #"{"type":"assistant","cwd":"/Users/kp/PepBox","message":{"role":"assistant","stop_reason":"tool_use","content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/Users/kp/PepBox/File\#(i).swift"}}]}}"# + "\n"
        text += #"{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"ok"}]}}"# + "\n"
    }
    try? text.write(to: url, atomically: true, encoding: .utf8)
    Crumb.set(30_000, "perf agents poll")
    var lines: [String] = []
    let readMs = timed { for _ in 0..<5 { lines = (AgentLogFiles.firstLine(of: url).map { [$0] } ?? []) + AgentLogFiles.tailLines(of: url, bytes: 400_000) } } / 5
    let parseMs = timed { for _ in 0..<5 { _ = AgentTranscriptParser.parseClaude(lines) } } / 5
    print(String(format: "PERF agents poll of a %.1f MB log: read tail %.1f ms + parse %d lines %.1f ms (every 1.5 s, up to 4 logs)",
                 Double(text.utf8.count) / 1_048_576, readMs, lines.count, parseMs))
}

// MARK: - Entry point

let scenarios: [String: (Int) -> Void] = [
    "clipboard": scenarioClipboard, "quicksearch": scenarioQuickSearchFuzz, "dates": scenarioDates,
    "focus": scenarioFocus, "snippets": scenarioSnippets, "http": scenarioHTTP, "localsend": scenarioLocalSend,
    "files": scenarioFiles, "agents": scenarioAgents, "transforms": scenarioTransforms, "perf": scenarioPerf
]

let arguments = CommandLine.arguments
guard arguments.count >= 2, let scenario = scenarios[arguments[1]] else {
    print("usage: \(arguments[0]) <\(scenarios.keys.sorted().joined(separator: "|"))> [start-case]")
    exit(2)
}
scenarioName = arguments[1]
startCase = arguments.count >= 3 ? Int(arguments[2]) ?? 0 : 0
setvbuf(stdout, nil, _IOLBF, 0)
Crumb.setup()
Crumb.startWatchdog(seconds: 20)
let elapsed = timed { scenario(startCase) }
Crumb.clear()
print("RESULT|\(scenarioName)|\(checks)|\(failures)|\(Int(elapsed))")
exit(failures == 0 ? 0 : 1)
