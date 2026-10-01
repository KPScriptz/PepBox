//
//  ClipboardStack.swift
//  PepBox
//
//  Pasting several clipboard items at once ("stacking"): the order they're
//  pasted in, and how a mixed stack is split into pastes. Text runs are joined
//  with the chosen separator into one paste; files and images follow in order
//  as their own pastes, since most apps take one image per ⌘V.
//

import Foundation

enum StackSeparator: String, CaseIterable, Identifiable {
    case newline, blankLine, space, comma, none

    static let key = "clipboardStackSeparator"

    var id: String { rawValue }

    var string: String {
        switch self {
        case .newline: return "\n"
        case .blankLine: return "\n\n"
        case .space: return " "
        case .comma: return ", "
        case .none: return ""
        }
    }

    var title: String {
        switch self {
        case .newline: return "New Line"
        case .blankLine: return "Blank Line"
        case .space: return "Space"
        case .comma: return "Comma"
        case .none: return "Nothing"
        }
    }

    static var current: StackSeparator {
        UserDefaults.standard.string(forKey: key).flatMap(StackSeparator.init(rawValue:)) ?? .newline
    }
}

enum ClipboardStack {
    /// What a stack entry is, independent of the app's ClipboardItem (so this can be tested).
    enum Entry: Equatable {
        case text(String)
        case file(String)   // path
        case image(UUID)    // loaded by the caller
    }

    /// One paste in a stack.
    enum Chunk: Equatable {
        case text(String)
        case files([String])
        case image(UUID)
    }

    /// Consecutive text becomes one paste (joined), consecutive files one paste, each image its own.
    static func plan(_ entries: [Entry], separator: StackSeparator) -> [Chunk] {
        var chunks: [Chunk] = []
        var run: String?  // the text run so far, grown in place (rebuilding it for every item is quadratic)
        for entry in entries {
            if case .text(let text) = entry {
                if run == nil { run = text } else { run! += separator.string + text }
                continue
            }
            if let text = run { chunks.append(.text(text)); run = nil }
            switch (entry, chunks.last) {
            case (.file(let path), .files(let previous)?):
                chunks[chunks.count - 1] = .files(previous + [path])
            case (.file(let path), _):
                chunks.append(.files([path]))
            case (.image(let id), _):
                chunks.append(.image(id))
            case (.text, _):
                break  // joined above
            }
        }
        if let text = run { chunks.append(.text(text)) }
        return chunks
    }

    /// Keeps the order items were picked in. Items still selected keep their place; newly
    /// selected ones go at the end, several at once (a range, Select All) oldest first.
    static func reconcile(order: [UUID], selected: Set<UUID>, dates: [UUID: Date]) -> [UUID] {
        var kept = order.filter(selected.contains)
        let added = selected.subtracting(kept)
            .sorted { (dates[$0] ?? .distantPast, $0.uuidString) < (dates[$1] ?? .distantPast, $1.uuidString) }
        kept += added
        return kept
    }
}
