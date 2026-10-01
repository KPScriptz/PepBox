// Scenarios: six months of Claude Code / Codex session logs through the Agents parser
// (with truncation, garbage and a growing log file read by its tail), and text transforms.

import Foundation

// MARK: - Agents

private enum ClaudeEvent {
    case prompt(String, attachments: Bool)
    case command(String)                 // "<command-name>…" user text, not a prompt
    case thinking, text
    case toolUse(name: String, input: [String: Any], sidechain: Bool)
    case toolResult
    case endTurn
    case garbage(String)
}

private struct ClaudeReference {
    var tools: [String] = []
    var toolCount = 0
    var edits = 0
    var state: AgentSnapshot.State?
    var pending = false
    var pendingName: String?
    var sawPrompt = false

    mutating func apply(_ event: ClaudeEvent) {
        switch event {
        case .prompt:
            tools = []; toolCount = 0; edits = 0; state = .thinking; pending = false; sawPrompt = true
        case .command, .garbage: break
        case .thinking: state = .thinking
        case .text: state = .writing
        case .toolUse(let name, let input, let sidechain):
            guard !sidechain else { return }
            let label = AgentTranscriptParser.toolLabel(name: name, input: input)
            tools.append(label); toolCount += 1
            if ["Edit", "Write", "MultiEdit", "NotebookEdit"].contains(name) { edits += 1 }
            state = .tool(label); pending = true; pendingName = name
        case .toolResult: pending = false; state = .thinking
        case .endTurn: state = .done; pending = false
        }
    }
}

private func jsonLine(_ object: [String: Any]) -> String {
    String(decoding: (try? JSONSerialization.data(withJSONObject: object)) ?? Data(), as: UTF8.self)
}

private func encode(_ event: ClaudeEvent, cwd: String, time: String) -> String {
    switch event {
    case .prompt(let text, let attachments):
        let content: Any = attachments ? [["type": "image", "source": [:]], ["type": "text", "text": text]] as Any : text
        return jsonLine(["type": "user", "cwd": cwd, "timestamp": time, "message": ["role": "user", "content": content]])
    case .command(let text):
        return jsonLine(["type": "user", "cwd": cwd, "message": ["role": "user", "content": text]])
    case .thinking:
        return jsonLine(["type": "assistant", "message": ["role": "assistant", "content": [["type": "thinking", "thinking": "hmm"]]]])
    case .text:
        return jsonLine(["type": "assistant", "message": ["role": "assistant", "content": [["type": "text", "text": "Working…"]]]])
    case .toolUse(let name, let input, let sidechain):
        return jsonLine(["type": "assistant", "isSidechain": sidechain, "cwd": cwd,
                         "message": ["role": "assistant", "stop_reason": "tool_use", "content": [["type": "tool_use", "name": name, "input": input]]]])
    case .toolResult:
        return jsonLine(["type": "user", "message": ["role": "user", "content": [["type": "tool_result", "content": "ok"]]]])
    case .endTurn:
        return jsonLine(["type": "assistant", "message": ["role": "assistant", "stop_reason": "end_turn", "content": [["type": "text", "text": "Done."]]]])
    case .garbage(let text):
        return text
    }
}

private func randomTool(_ rng: inout RNG) -> (String, [String: Any]) {
    switch rng.int(9) {
    case 0: return ("Edit", ["file_path": "/Users/kp/PepBox/\(rng.pick(["App.swift", "a b/ü.swift", ""]))"])
    case 1: return ("Write", ["file_path": "/tmp/new.txt"])
    case 2: return ("Bash", ["command": rng.pick(["xcodebuild -scheme X", "", "   ", "ls"]), "description": rng.pick(["", "Build the app"])])
    case 3: return ("Read", [:])
    case 4: return ("Grep", ["pattern": rng.pick(["TODO", ""])])
    case 5: return ("mcp__github__create_issue", ["title": "x"])
    case 6: return ("Task", ["description": "explore"])
    case 7: return ("MultiEdit", ["file_path": NSNull()])
    default: return (rng.pick(["WebFetch", "", "__", "NotebookEdit"]), ["notebook_path": "/x/n.ipynb"])
    }
}

private let garbageLines: [String] = [
    "not json", "", "{", "[]", "42", "null", "{\"type\":5}", "{\"type\":\"user\",\"message\":\"str\"}",
    "{\"type\":\"assistant\",\"message\":{\"content\":null}}", "{\"type\":\"user\",\"message\":{\"content\":[{\"type\":7}]}}",
    "\u{FEFF}{\"type\":\"user\"}", String(repeating: "x", count: 2_000_000), "{\"a\":" + String(repeating: "[", count: 100_000)
]

func scenarioAgents(start: Int) {
    var rng = RNG(0xA6E7)
    let fm = FileManager.default
    let logURL = fm.temporaryDirectory.appendingPathComponent("pepbox-sim-agents-\(getpid()).jsonl")
    try? fm.removeItem(at: logURL)
    fm.createFile(atPath: logURL.path, contents: nil)
    defer { try? fm.removeItem(at: logURL) }
    let handle = try! FileHandle(forWritingTo: logURL)
    defer { try? handle.close() }

    var sessions = 0, parses = 0, tailPolls = 0
    var pollMs: [Double] = []
    var turnsSinceTail = ClaudeReference()   // reference for the whole long-running log
    var lastPromptBytes = 0                  // file offset of the latest prompt

    for day in 0..<182 {
        for _ in 0..<rng.range(0...6) {
            sessions += 1
            var events: [ClaudeEvent] = []
            for _ in 0..<rng.range(1...6) {   // turns
                events.append(rng.chance(0.15) ? .command("<command-name>/clear</command-name>") : .prompt("fix bug \(sessions)", attachments: rng.chance(0.2)))
                for _ in 0..<rng.range(0...30) {
                    switch rng.int(10) {
                    case 0: events.append(.thinking)
                    case 1: events.append(.text)
                    case 2: events.append(.garbage(rng.pick(garbageLines.dropLast(2) + ["tail -f junk"])))
                    default:
                        let (name, input) = randomTool(&rng)
                        events.append(.toolUse(name: name, input: input, sidechain: rng.chance(0.15)))
                        if rng.chance(0.85) { events.append(.toolResult) }
                    }
                }
                if rng.chance(0.7) { events.append(.endTurn) }
            }
            let cwd = rng.pick(["/Users/kp/PepBox", "/Users/kp/KPScriptz/robobooth", "/", "/tmp/a b"])
            let lines = events.map { encode($0, cwd: cwd, time: "2026-10-\(String(format: "%02d", day % 28 + 1))T10:00:00.000Z") }

            // Parse at random cut points, sometimes cutting the last line mid-way.
            for _ in 0..<4 {
                let cut = rng.range(0...lines.count)
                var prefix = Array(lines.prefix(cut))
                var reference = ClaudeReference()
                for event in events.prefix(cut) { reference.apply(event) }
                if !prefix.isEmpty, rng.chance(0.3) {
                    let last = prefix.removeLast()
                    prefix.append(String(last.prefix(rng.int(max(1, last.count)))))   // half-written line
                    reference = ClaudeReference()
                    for event in events.prefix(cut - 1) { reference.apply(event) }
                }
                Crumb.set(parses, "agents session \(sessions) cut \(cut)")
                parses += 1
                let snapshot = AgentTranscriptParser.parseClaude(prefix)
                verify(snapshot, reference, label: "session \(sessions) cut \(cut)")
            }

            // Append to the long-running log the monitor tails (400 KB window).
            let blob = Data((lines.joined(separator: "\n") + "\n").utf8)
            var offset = Int((try? handle.seekToEnd()) ?? 0)
            for (event, line) in zip(events, lines) {
                if case .prompt = event { lastPromptBytes = offset }
                turnsSinceTail.apply(event)
                offset += line.utf8.count + 1
            }
            try? handle.write(contentsOf: blob)
        }
        // The monitor polls the newest log every few seconds; do one poll per day.
        let fileSize = Int((try? handle.offsetInFile) ?? 0)
        var lines: [String] = []
        let ms = timed {
            lines = (AgentLogFiles.firstLine(of: logURL).map { [$0] } ?? []) + AgentLogFiles.tailLines(of: logURL, bytes: 400_000)
            _ = AgentTranscriptParser.parseClaude(lines)
        }
        pollMs.append(ms)
        tailPolls += 1
        if fileSize - lastPromptBytes < 399_000, turnsSinceTail.sawPrompt {
            verify(AgentTranscriptParser.parseClaude(lines), turnsSinceTail, label: "tail poll day \(day) (\(fileSize / 1024) KB log)")
        }
    }
    let finalSize = Int((try? handle.offsetInFile) ?? 0)
    // Pathological lines straight into the parser.
    for (index, line) in garbageLines.enumerated() {
        guard step(100_000 + index, "agents garbage line \(index)") else { continue }
        _ = AgentTranscriptParser.parseClaude([line])
        _ = AgentTranscriptParser.parseCodex([line])
    }
    check(AgentTranscriptParser.parseClaude(garbageLines) == nil, "garbage alone yields no session")
    scenarioCodex(&rng)
    let average = pollMs.reduce(0, +) / Double(max(1, pollMs.count))
    note(String(format: "%d sessions, %d parses, %d tail polls of a log that grew to %.1f MB; poll avg %.1f ms, max %.1f ms",
                sessions, parses, tailPolls, Double(finalSize) / 1_048_576, average, pollMs.max() ?? 0))
    // Not a pass/fail budget: the monitor polls up to 4 logs every 1.5 s on a utility queue; see the report.
}

private func verify(_ snapshot: AgentSnapshot?, _ reference: ClaudeReference, label: String) {
    guard let expectedState = reference.state else {
        check(snapshot == nil, "no prompt/assistant yet should give no snapshot (\(label))")
        return
    }
    guard let snapshot else { check(false, "snapshot missing (\(label))"); return }
    expectEq(snapshot.toolCount, reference.toolCount, "tool count (\(label))")
    expectEq(snapshot.editCount, reference.edits, "edit count (\(label))")
    expectEq(snapshot.tools, Array(reference.tools.suffix(20)), "tool list (\(label))")
    expectEq(snapshot.state, reference.pending ? .tool(reference.tools.last ?? "") : expectedState, "state (\(label))")
    expectEq(snapshot.pendingTool, reference.pending ? reference.pendingName : nil, "pending tool (\(label))")
    check(snapshot.tools.count <= 20, "tool list capped at 20")
}

private func scenarioCodex(_ rng: inout RNG) {
    func line(_ type: String, _ payload: [String: Any]) -> String { jsonLine(["type": type, "timestamp": "2026-10-01T10:00:00.000Z", "payload": payload]) }
    for index in 0..<2_000 {
        var lines = [line("session_meta", ["cwd": "/Users/kp/site"])]
        var toolCount = 0, edits = 0
        var state: AgentSnapshot.State? = nil
        for _ in 0..<rng.range(0...40) {
            switch rng.int(8) {
            case 0: lines.append(line("event_msg", ["type": "user_message", "message": "go"])); toolCount = 0; edits = 0; state = .thinking
            case 1: lines.append(line("response_item", ["type": "reasoning"])); state = .thinking
            case 2: lines.append(line("event_msg", ["type": "agent_message"])); state = .writing
            case 3: lines.append(line("event_msg", ["type": "task_complete"])); state = .done
            case 4: lines.append(rng.pick(garbageLines.dropLast(2)))
            default:
                let patch = rng.chance(0.4)
                let args = patch ? "*** Begin Patch\n*** Update File: /x/\(rng.pick(["a.swift", "", "b c.js"]))\n" : rng.pick(["{\"cmd\":\"npm test\"}", "{\"command\":[\"bash\",\"-lc\",\"ls -la\"]}", "{", "", "{\"command\":[]}"])
                let name = patch ? "apply_patch" : rng.pick(["exec_command", "shell", ""])
                lines.append(line("response_item", ["type": rng.pick(["function_call", "custom_tool_call", "local_shell_call"]), "name": name, patch ? "input" : "arguments": args]))
                toolCount += 1
                if name == "apply_patch" { edits += 1 }
                state = .tool(AgentTranscriptParser.codexToolLabel(name: name, arguments: args))
            }
        }
        Crumb.set(200_000 + index, "codex session \(index)")
        let snapshot = AgentTranscriptParser.parseCodex(lines)
        expectEq(snapshot?.state, state, "codex state session \(index)")
        if state != nil {
            expectEq(snapshot?.toolCount, toolCount, "codex tool count session \(index)")
            expectEq(snapshot?.editCount, edits, "codex edits session \(index)")
            expectEq(snapshot?.project, "site", "codex project session \(index)")
        }
    }
}

// MARK: - Text transforms

private func randomJSON(_ rng: inout RNG, depth: Int = 0) -> Any {
    switch rng.int(depth > 4 ? 5 : 7) {
    case 0: return rng.pick(["", "a/b", "quote \" back\\slash", "tab\tnew\nline", "😀 e\u{301}", "\u{0}\u{1F}", "</script>"])
    case 1: return rng.pick([0, -1, Int.max, Int.min, 9_007_199_254_740_993]) as Int
    case 2: return rng.pick([0.1, -2.5e-300, 1e300, 3.141592653589793, 0.30000000000000004])
    case 3: return rng.chance(0.5)
    case 4: return NSNull()
    case 5: return (0..<rng.range(0...5)).map { _ in randomJSON(&rng, depth: depth + 1) }
    default:
        var dict: [String: Any] = [:]
        for _ in 0..<rng.range(0...5) { dict[rng.pick(["a", "B", "ключ", "", "a b", "z", "🙂"])] = randomJSON(&rng, depth: depth + 1) }
        return dict
    }
}

private func randomText(_ rng: inout RNG) -> String {
    let pieces = ["hello", "World", " ", "  ", "\n", "\r\n", "\t", "line", "a10", "a2", "Zebra", "zebra", "ÉCOLE", "école", "İ", "ß", "ﬁ",
                  "👨‍👩‍👧‍👦", "🇺🇸", "e\u{301}", "مرحبا", "שלום", "日本", "\u{200B}", "\u{2028}", ".", "!", "?", "-", "_", "https://x.com/a",
                  "\u{0}", "Ǆ", "ǅ", "Σ", "ς", "ΐ", "ŉ", "ﬀ", "Ⅻ", "½", "١٢", "\u{FEFF}", "\u{00A0}"]
    return (0..<rng.range(0...60)).map { _ in rng.pick(pieces) }.joined()
}

func scenarioTransforms(start: Int) {
    var rng = RNG(0x7E87)
    var idempotenceFailures: [String: String] = [:]
    for index in 0..<12_000 {
        let text = index % 500 == 0 ? String(repeating: randomText(&rng) + "\n", count: 2_000) : randomText(&rng)
        guard step(index, text) else { continue }
        for transform in TextTransform.allCases {
            let once = transform.apply(text)
            // Idempotent transforms: applying twice must equal applying once.
            if [.trim, .uniqueLines, .sortLines, .slug, .singleLine, .lowercase].contains(transform), let once {
                let twice = transform.apply(once)
                if twice != once, idempotenceFailures[transform.rawValue] == nil {
                    idempotenceFailures[transform.rawValue] = text
                }
                checks += 1
            }
        }
        if let sorted = TextTransform.sortLines.apply(text) {
            expectEq(sorted.split(separator: "\n", omittingEmptySubsequences: false).count,
                     text.split(separator: "\n", omittingEmptySubsequences: false).count, "sort keeps every line")
        }
        if let unique = TextTransform.uniqueLines.apply(text) {
            let lines = unique.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            expectEq(Set(lines).count, lines.count, "unique lines has no duplicates")
        }
    }
    for (name, text) in idempotenceFailures.sorted(by: { $0.key < $1.key }) {
        let once = TextTransform(rawValue: name)!.apply(text) ?? ""
        let twice = TextTransform(rawValue: name)!.apply(once) ?? ""
        check(false, "\(name) is not idempotent: \(short(text, 60)) → \(short(once, 60)) → \(short(twice, 60))")
    }
    // Pretty JSON round-trips any valid JSON.
    for index in 0..<3_000 {
        let value = randomJSON(&rng)
        guard let compact = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]) else { continue }
        let text = String(decoding: compact, as: UTF8.self)
        guard step(30_000 + index, text) else { continue }
        guard let pretty = TextTransform.prettyJSON.apply(text) else { check(false, "pretty JSON rejected valid JSON \(short(text))"); continue }
        let reparsed = try? JSONSerialization.jsonObject(with: Data(pretty.utf8), options: [.fragmentsAllowed])
        check(reparsed.map { ($0 as AnyObject).isEqual(value) } == true || text == "null", "pretty JSON changed the value: \(short(text, 80))")
        expectEq(TextTransform.prettyJSON.apply(pretty), pretty, "pretty JSON is idempotent")
    }
    for depth in [100, 513, 10_000, 200_000] {
        guard step(40_000 + depth, "pretty JSON nesting depth \(depth)") else { continue }
        let deep = String(repeating: "[", count: depth) + String(repeating: "]", count: depth)
        _ = TextTransform.prettyJSON.apply(deep)
        checks += 1
    }
    note("12,000 random texts × \(TextTransform.allCases.count) transforms; 3,000 JSON documents; nesting up to 200,000 deep")
}
