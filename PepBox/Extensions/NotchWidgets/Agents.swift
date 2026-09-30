//
//  Agents.swift
//  PepBox
//
//  Live progress of local coding agents (Claude Code, Codex) beside the notch
//  and in a shelf panel. Reads their session logs on this Mac only
//  (~/.claude/projects, ~/.codex/sessions): no network, nothing sent anywhere.
//

import SwiftUI
import AppKit

// MARK: - Parsing

struct AgentSnapshot: Equatable {
    enum Agent: String { case claude = "Claude", codex = "Codex" }
    enum State: Equatable {
        case thinking
        case writing
        case tool(String)      // "Edit Agents.swift"
        case waiting           // tool call with no result yet: usually a permission prompt
        case done
    }

    var agent: Agent
    var project: String
    var state: State
    /// Recent tool calls since the last prompt, newest last (up to 20).
    var tools: [String]
    var toolCount: Int
    var editCount: Int
    var promptStart: Date?
    /// Raw name of a tool call still waiting for its result ("Edit", "Bash"), if any.
    var pendingTool: String? = nil
}

enum AgentTranscriptParser {
    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Claude Code session log lines (JSONL), oldest first.
    static func parseClaude(_ lines: [String]) -> AgentSnapshot? {
        var project = ""
        var tools: [String] = []
        var toolCount = 0
        var edits = 0
        var promptStart: Date?
        var state: AgentSnapshot.State?
        var pendingTool = false
        var pendingName: String?

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let entry = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  entry["isSidechain"] as? Bool != true else { continue }
            if let cwd = entry["cwd"] as? String { project = (cwd as NSString).lastPathComponent }
            let type = entry["type"] as? String
            let message = entry["message"] as? [String: Any]

            if type == "user", let message {
                if let text = message["content"] as? String, !text.hasPrefix("<") {
                    // A real prompt starts a new turn.
                    tools = []
                    toolCount = 0
                    edits = 0
                    promptStart = (entry["timestamp"] as? String).flatMap(iso.date(from:))
                    state = .thinking
                    pendingTool = false
                } else if let parts = message["content"] as? [[String: Any]] {
                    if parts.contains(where: { $0["type"] as? String == "tool_result" }) {
                        pendingTool = false
                        state = .thinking
                    } else if parts.contains(where: { $0["type"] as? String == "text" }) {
                        // Prompt sent with attachments (images, pasted text).
                        tools = []
                        toolCount = 0
                        edits = 0
                        promptStart = (entry["timestamp"] as? String).flatMap(iso.date(from:))
                        state = .thinking
                        pendingTool = false
                    }
                }
            } else if type == "assistant", let message, let parts = message["content"] as? [[String: Any]] {
                for part in parts {
                    switch part["type"] as? String {
                    case "thinking": state = .thinking
                    case "text": state = .writing
                    case "tool_use":
                        let name = part["name"] as? String ?? "Tool"
                        let input = part["input"] as? [String: Any] ?? [:]
                        let label = toolLabel(name: name, input: input)
                        tools.append(label)
                        toolCount += 1
                        if ["Edit", "Write", "MultiEdit", "NotebookEdit"].contains(name) { edits += 1 }
                        state = .tool(label)
                        pendingTool = true
                        pendingName = name
                    default: break
                    }
                }
                if message["stop_reason"] as? String == "end_turn" {
                    state = .done
                    pendingTool = false
                }
            }
        }
        guard let state else { return nil }
        return AgentSnapshot(agent: .claude, project: project, state: pendingTool ? .tool(tools.last ?? "") : state,
                             tools: Array(tools.suffix(20)), toolCount: toolCount, editCount: edits, promptStart: promptStart,
                             pendingTool: pendingTool ? pendingName : nil)
    }

    /// Codex rollout log lines (JSONL), oldest first.
    static func parseCodex(_ lines: [String]) -> AgentSnapshot? {
        var project = ""
        var tools: [String] = []
        var toolCount = 0
        var edits = 0
        var promptStart: Date?
        var state: AgentSnapshot.State?

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let entry = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = entry["payload"] as? [String: Any] else { continue }
            let kind = payload["type"] as? String
            if let cwd = payload["cwd"] as? String { project = (cwd as NSString).lastPathComponent }
            switch (entry["type"] as? String, kind) {
            case ("event_msg", "user_message"), ("event_msg", "task_started"):
                tools = []
                toolCount = 0
                edits = 0
                promptStart = (entry["timestamp"] as? String).flatMap(iso.date(from:))
                state = .thinking
            case ("response_item", "reasoning"):
                state = .thinking
            case ("event_msg", "agent_message"):
                state = .writing
            case ("response_item", "function_call"), ("response_item", "custom_tool_call"), ("response_item", "local_shell_call"):
                let name = payload["name"] as? String ?? "shell"
                let label = codexToolLabel(name: name, arguments: payload["arguments"] as? String ?? payload["input"] as? String)
                tools.append(label)
                toolCount += 1
                if name == "apply_patch" { edits += 1 }
                state = .tool(label)
            case ("event_msg", "task_complete"):
                state = .done
            default:
                break
            }
        }
        guard let state else { return nil }
        return AgentSnapshot(agent: .codex, project: project, state: state, tools: Array(tools.suffix(20)),
                             toolCount: toolCount, editCount: edits, promptStart: promptStart)
    }

    static func toolLabel(name: String, input: [String: Any]) -> String {
        let file = (input["file_path"] as? String ?? input["notebook_path"] as? String).map { ($0 as NSString).lastPathComponent }
        switch name {
        case "Edit", "MultiEdit", "Write", "Read", "NotebookEdit":
            return file.map { "\(name) \($0)" } ?? name
        case "Bash":
            if let description = input["description"] as? String, !description.isEmpty { return description }
            let command = (input["command"] as? String ?? "").split(separator: " ").first.map(String.init) ?? ""
            return command.isEmpty ? "Bash" : "Run \(command)"
        case "Grep", "Glob":
            return "Search \(input["pattern"] as? String ?? "")".trimmingCharacters(in: .whitespaces)
        case "WebFetch", "WebSearch":
            return "Browse the web"
        case "Agent", "Task":
            return (input["description"] as? String).map { "Agent: \($0)" } ?? "Subagent"
        default:
            // MCP tools look like mcp__server__tool_name.
            let short = name.components(separatedBy: "__").last ?? name
            return short.replacingOccurrences(of: "_", with: " ")
        }
    }

    static func codexToolLabel(name: String, arguments: String?) -> String {
        if name == "apply_patch" || arguments?.contains("*** Update File:") == true || arguments?.contains("*** Add File:") == true {
            if let arguments, let range = arguments.range(of: #"\*\*\* (Update|Add) File: [^\n\\]+"#, options: .regularExpression) {
                let path = arguments[range].components(separatedBy: "File: ").last ?? ""
                return "Edit \((path as NSString).lastPathComponent)"
            }
            return "Edit files"
        }
        if let arguments, let data = arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let command = (json["command"] as? [String])?.last ?? json["cmd"] as? String ?? json["command"] as? String
            if let first = command?.split(separator: " ").first { return "Run \(first)" }
        }
        return name.replacingOccurrences(of: "_", with: " ")
    }
}

// MARK: - Monitor

@Observable
final class AgentsMonitor {
    static let shared = AgentsMonitor()

    /// The most recently active session, if one was active in the last few minutes.
    /// The session to show beside the notch: one that needs you first, else the most recent.
    private(set) var snapshot: AgentSnapshot?
    /// Every session active in the last few minutes, most recent first (up to 4).
    private(set) var sessions: [AgentSnapshot] = []
    private(set) var lastActivity: Date?
    private(set) var now = Date()

    private var timer: Timer?
    private var watchers = 0
    private let queue = DispatchQueue(label: "PepBox.AgentsMonitor", qos: .utility)

    private let home = FileManager.default.homeDirectoryForCurrentUser

    /// Runs only while the Agents widget is installed and on.
    func sync() {
        let enabled = NotchWidgetKind.agents.isAvailable
        guard enabled != (timer != nil) else { return }
        setEnabled(enabled)
    }

    func setEnabled(_ enabled: Bool) {
        timer?.invalidate()
        timer = nil
        snapshot = nil
        guard enabled else { return }
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        poll()
    }

    /// Seconds since the log last changed; a tool call that sits unanswered this long is waiting on you.
    private static let waitingAfter: TimeInterval = 8
    /// Hide the activity this long after the agent finishes.
    private static let doneLinger: TimeInterval = 10
    /// Treat a session as over after this long without log changes.
    private static let staleAfter: TimeInterval = 180

    /// Tools that normally finish instantly. If one sits unanswered, Claude Code is almost
    /// certainly showing a permission prompt; long runners like Bash are just busy.
    private static let instantTools: Set<String> = ["Edit", "MultiEdit", "Write", "NotebookEdit", "Read", "Glob", "Grep", "WebFetch"]

    private func poll() {
        queue.async { [weak self] in
            guard let self else { return }
            let now = Date()
            let recent = self.recentLogs()
                .filter { now.timeIntervalSince($0.modified) < Self.staleAfter }
                .sorted { $0.modified > $1.modified }
                .prefix(4)
            var sessions: [AgentSnapshot] = []
            for log in recent {
                // The first line carries the working folder (Codex session_meta), which the tail may miss.
                let lines = (Self.firstLine(of: log.url).map { [$0] } ?? []) + Self.tailLines(of: log.url, bytes: 400_000)
                guard var parsed = log.agent == .claude ? AgentTranscriptParser.parseClaude(lines) : AgentTranscriptParser.parseCodex(lines) else { continue }
                let idle = now.timeIntervalSince(log.modified)
                if case .tool = parsed.state, idle > Self.waitingAfter, log.agent == .claude,
                   let pending = parsed.pendingTool, Self.instantTools.contains(pending) {
                    parsed.state = .waiting
                }
                if parsed.state == .done, idle > Self.doneLinger { continue }
                sessions.append(parsed)
            }
            let primary = sessions.first { $0.state == .waiting } ?? sessions.first
            DispatchQueue.main.async {
                self.sessions = sessions
                self.snapshot = primary
                self.lastActivity = recent.first?.modified
                self.now = Date()
            }
        }
    }

    private struct LogFile { let url: URL; let modified: Date; let agent: AgentSnapshot.Agent }

    private func recentLogs() -> [LogFile] {
        var files: [LogFile] = []
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey]

        // Claude Code: ~/.claude/projects/<project>/<session>.jsonl (subagent logs live in subfolders; skipped).
        let claudeRoot = home.appendingPathComponent(".claude/projects")
        for project in (try? fm.contentsOfDirectory(at: claudeRoot, includingPropertiesForKeys: keys)) ?? [] {
            guard let modified = try? project.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                  Date().timeIntervalSince(modified) < 86_400 * 2 else { continue }
            for file in (try? fm.contentsOfDirectory(at: project, includingPropertiesForKeys: keys)) ?? [] where file.pathExtension == "jsonl" {
                if let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                    files.append(LogFile(url: file, modified: date, agent: .claude))
                }
            }
        }

        // Codex: ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl, today and yesterday.
        let calendar = Calendar.current
        for dayOffset in [0, -1] {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            let folder = home.appendingPathComponent(String(format: ".codex/sessions/%04d/%02d/%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0))
            for file in (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)) ?? [] where file.pathExtension == "jsonl" {
                if let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                    files.append(LogFile(url: file, modified: date, agent: .codex))
                }
            }
        }
        return files
    }

    static func firstLine(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: 16_384)) ?? Data()
        guard let newline = data.firstIndex(of: 0x0A) else { return nil }
        return String(decoding: data[..<newline], as: UTF8.self)
    }

    /// The last `bytes` of a file as whole lines.
    static func tailLines(of url: URL, bytes: Int) -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let start = size > UInt64(bytes) ? size - UInt64(bytes) : 0
        try? handle.seek(toOffset: start)
        let data = (try? handle.readToEnd()) ?? Data()
        var lines = String(decoding: data, as: UTF8.self).components(separatedBy: "\n")
        if start > 0, !lines.isEmpty { lines.removeFirst() }  // partial first line
        return lines.filter { !$0.isEmpty }
    }

    // MARK: Presentation

    var statusText: String? { snapshot.map(Self.status) }

    static func status(_ snapshot: AgentSnapshot) -> String {
        switch snapshot.state {
        case .thinking: return "Thinking"
        case .writing: return "Writing"
        case .tool(let label): return label
        case .waiting: return "Needs you"
        case .done: return "Done"
        }
    }

    var tint: Color { snapshot.map(Self.tint) ?? .orange }

    static func tint(_ snapshot: AgentSnapshot) -> Color {
        if snapshot.state == .waiting { return .yellow }
        if snapshot.state == .done { return .green }
        return snapshot.agent == .claude ? Color(red: 0.85, green: 0.47, blue: 0.34) : .cyan
    }

    var liveActivity: LiveActivity? {
        guard let snapshot, let text = statusText else { return nil }
        let short = text.count > 22 ? String(text.prefix(21)) + "…" : text
        let icon: String
        switch snapshot.state {
        case .waiting: icon = "hand.raised.fill"
        case .done: icon = "checkmark.circle.fill"
        default: icon = snapshot.agent == .claude ? "sparkle" : "chevron.left.forwardslash.chevron.right"
        }
        return LiveActivity(id: "agent-\(snapshot.agent.rawValue)", icon: icon, tint: tint, text: short, progress: nil)
    }
}

// MARK: - Panel

struct AgentsNotchView: View {
    var monitor: AgentsMonitor

    var body: some View {
        if monitor.sessions.count > 1 {
            sessionList
        } else if let snapshot = monitor.snapshot {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: snapshot.agent == .claude ? "sparkle" : "chevron.left.forwardslash.chevron.right")
                        .foregroundStyle(monitor.tint)
                    Text("\(snapshot.agent.rawValue) · \(snapshot.project)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(monitor.statusText ?? "")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(monitor.tint)
                        .lineLimit(1)
                }
                HStack(spacing: 14) {
                    stat("\(snapshot.toolCount)", "tool calls")
                    stat("\(snapshot.editCount)", "edits")
                    if let start = snapshot.promptStart {
                        stat(Self.elapsed(from: start, to: monitor.now), "this turn")
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(snapshot.tools.suffix(4).enumerated()), id: \.offset) { _, tool in
                        HStack(spacing: 6) {
                            Circle().fill(.white.opacity(0.35)).frame(width: 4, height: 4)
                            Text(tool)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("No agent running")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text("Start Claude Code or Codex and its progress shows up here and beside the notch.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    /// Several agents at once: one compact row each.
    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(monitor.sessions.count) agents running")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            ForEach(Array(monitor.sessions.enumerated()), id: \.offset) { _, session in
                HStack(spacing: 8) {
                    Image(systemName: session.agent == .claude ? "sparkle" : "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AgentsMonitor.tint(session))
                        .frame(width: 14)
                    Text(session.project.isEmpty ? session.agent.rawValue : session.project)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(width: 130, alignment: .leading)
                    Text(AgentsMonitor.status(session))
                        .font(.system(size: 11))
                        .foregroundStyle(AgentsMonitor.tint(session))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(session.toolCount) calls · \(session.editCount) edits")
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    static func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return seconds < 3600 ? String(format: "%d:%02d", seconds / 60, seconds % 60)
                              : String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}
