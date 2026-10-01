// Scenario: six months of clipboard stacking (ClipboardStack.reconcile + plan).

import Foundation

private struct HistoryItem {
    let id: UUID
    let date: Date
    let entry: ClipboardStack.Entry
}

private func randomClipText(_ rng: inout RNG) -> String {
    switch rng.int(12) {
    case 0: return ""
    case 1: return "\n"
    case 2: return ", "
    case 3: return String(repeating: "lorem ipsum ", count: rng.range(50...900))   // long paste
    case 4: return "line one\nline two\n\nline four"
    case 5: return "👨‍👩‍👧‍👦 🇺🇸 e\u{301} مرحبا שלום"
    case 6: return "  padded  "
    default: return rng.pick(["https://pivotxp.com/a?b=1", "kyle@pivotxp.com", "SELECT * FROM t;", "42", "TODO: ship it",
                              "func a() { }", "Hello, world", "a, b", "x"]) + (rng.chance(0.5) ? " \(rng.int(1000))" : "")
    }
}

func scenarioClipboard(start: Int) {
    var rng = RNG(0xC11B)
    var history: [HistoryItem] = []       // newest last; the app keeps a capped history
    let historyCap = 500
    var clock = Date(timeIntervalSince1970: 1_790_812_800)  // 2026-10-01 00:00 CDT-ish
    var stacks = 0, selectionOps = 0, planned = 0

    for day in 0..<182 {
        clock = Date(timeIntervalSince1970: 1_790_812_800 + Double(day) * 86_400)
        // A power user copies 20–120 things a day.
        for _ in 0..<rng.range(20...120) {
            clock += Double(rng.range(0...600))   // sometimes several copies in the same second (ties)
            let entry: ClipboardStack.Entry
            switch rng.int(10) {
            case 0, 1: entry = .file("/Users/kp/Desktop/file \(rng.int(5000)).\(rng.pick(["pdf", "png", "zip", "txt"]))")
            case 2: entry = .image(rng.uuid())
            default: entry = .text(randomClipText(&rng))
            }
            history.append(HistoryItem(id: rng.uuid(), date: clock, entry: entry))
        }
        if history.count > historyCap { history.removeFirst(history.count - historyCap) }
        let byID = Dictionary(uniqueKeysWithValues: history.map { ($0.id, $0) })
        var dates = Dictionary(uniqueKeysWithValues: history.map { ($0.id, $0.date) })
        if rng.chance(0.1), let victim = history.randomElement(using: &rng) {
            dates[victim.id] = nil   // an item whose date is missing sorts as distant past
        }
        let display = history.reversed().map(\.id)   // the list shows newest first

        for _ in 0..<rng.range(4...12) {
            stacks += 1
            Crumb.set(stacks, "clipboard day \(day) stack \(stacks)")
            var order: [UUID] = []
            var selected = Set<UUID>()
            for _ in 0..<rng.range(1...12) {
                selectionOps += 1
                let before = order
                var newlyAdded = Set<UUID>()
                switch rng.int(10) {
                case 0...4:   // ⌘-click toggles one
                    let id = rng.pick(display)
                    if selected.remove(id) == nil { selected.insert(id); newlyAdded.insert(id) }
                case 5, 6:    // ⇧-click adds a range
                    let a = rng.int(display.count), b = min(display.count - 1, a + rng.range(1...40))
                    for id in display[a...b] where selected.insert(id).inserted { newlyAdded.insert(id) }
                case 7:       // Select All
                    for id in display where selected.insert(id).inserted { newlyAdded.insert(id) }
                case 8:       // deselect a random few
                    for id in selected.shuffled(using: &rng).prefix(rng.range(1...5)) { selected.remove(id) }
                default:      // Deselect All
                    selected.removeAll()
                }
                order = ClipboardStack.reconcile(order: order, selected: selected, dates: dates)

                // Invariants
                check(Set(order).count == order.count, "reconcile produced duplicates (stack \(stacks))")
                check(Set(order) == selected, "reconcile order != selection (stack \(stacks)): \(order.count) vs \(selected.count)")
                let kept = before.filter(selected.contains)
                check(Array(order.prefix(kept.count)) == kept, "reconcile moved still-selected items (stack \(stacks))")
                let appended = Array(order.dropFirst(kept.count))
                let expectedAppended = appended.sorted {
                    let l = dates[$0] ?? .distantPast, r = dates[$1] ?? .distantPast
                    return l != r ? l < r : $0.uuidString < $1.uuidString
                }
                check(appended == expectedAppended, "reconcile new items not oldest-first (stack \(stacks))")
                check(Set(appended).isSubset(of: newlyAdded.union(Set(before).subtracting(kept)).union(selected)), "reconcile appended unknown ids")
            }

            for separator in [rng.pick(StackSeparator.allCases), rng.pick(StackSeparator.allCases)] {
                let entries = order.compactMap { byID[$0]?.entry }
                let chunks = ClipboardStack.plan(entries, separator: separator)
                planned += 1
                verifyPlan(entries, chunks, separator, label: "stack \(stacks) \(separator)")
            }
        }
    }
    note("\(stacks) stacks, \(selectionOps) selection changes, \(planned) plans over 182 days; history capped at \(historyCap)")
}

/// Plan invariants, checked from first principles.
func verifyPlan(_ entries: [ClipboardStack.Entry], _ chunks: [ClipboardStack.Chunk], _ separator: StackSeparator, label: String) {
    // Expected runs: maximal runs of text, maximal runs of files, each image alone.
    var runs: [ClipboardStack.Chunk] = []
    var texts: [String] = [], files: [String] = []
    func flush() {
        if !texts.isEmpty { runs.append(.text(texts.joined(separator: separator.string))); texts = [] }
        if !files.isEmpty { runs.append(.files(files)); files = [] }
    }
    for entry in entries {
        switch entry {
        case .text(let t): if !files.isEmpty { flush() }; texts.append(t)
        case .file(let p): if !texts.isEmpty { flush() }; files.append(p)
        case .image(let id): flush(); runs.append(.image(id))
        }
    }
    flush()
    expectEq(chunks.count, runs.count, "plan chunk count (\(label))")
    check(chunks == runs, "plan differs from run-joined reference (\(label))")
    let images = entries.compactMap { if case .image(let id) = $0 { return id } else { return nil } }
    let planImages = chunks.compactMap { if case .image(let id) = $0 { return id } else { return nil } }
    expectEq(planImages, images, "plan keeps every image in order (\(label))")
    let allFiles = entries.compactMap { if case .file(let p) = $0 { return p } else { return nil } }
    let planFiles = chunks.flatMap { if case .files(let p) = $0 { return p } else { return [] } }
    expectEq(planFiles, allFiles, "plan keeps every file in order (\(label))")
    for (a, b) in zip(chunks, chunks.dropFirst()) {
        if case .text = a, case .text = b { check(false, "two text pastes in a row (\(label))") }
        if case .files = a, case .files = b { check(false, "two file pastes in a row (\(label))") }
    }
    for chunk in chunks {
        if case .files(let p) = chunk { check(!p.isEmpty, "empty file paste (\(label))") }
    }
}

