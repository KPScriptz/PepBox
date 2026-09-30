//
//  QuickNotes.swift
//  PepBox
//
//  A notepad on the shelf: jot something down without switching apps.
//  Notes are saved as JSON in Application Support and kept until deleted.
//

import SwiftUI

struct QuickNote: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var modified: Date

    var title: String {
        let firstLine = text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "New Note" : trimmed
    }
}

@Observable
final class QuickNotesStore {
    static let shared = QuickNotesStore()

    private(set) var notes: [QuickNote] = []
    var selectedID: UUID?

    private let fileURL: URL = {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PepBox", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("QuickNotes.json")
    }()
    private var saveWork: DispatchWorkItem?

    private init() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([QuickNote].self, from: data) {
            notes = saved
        }
        if notes.isEmpty { notes = [QuickNote(text: "", modified: Date())] }
        selectedID = notes.first?.id
    }

    var selected: QuickNote? { notes.first { $0.id == selectedID } }

    /// A new note with this text, shown first (from Quick Search "note …").
    func addNote(text: String) {
        let note = QuickNote(text: text, modified: Date())
        notes.insert(note, at: 0)
        selectedID = note.id
        scheduleSave()
    }

    func update(_ id: UUID, text: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }), notes[index].text != text else { return }
        notes[index].text = text
        notes[index].modified = Date()
        scheduleSave()
    }

    func add() {
        // Reuse an empty note instead of stacking blanks.
        if let empty = notes.first(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            selectedID = empty.id
            return
        }
        let note = QuickNote(text: "", modified: Date())
        notes.insert(note, at: 0)
        selectedID = note.id
        scheduleSave()
    }

    func delete(_ id: UUID) {
        notes.removeAll { $0.id == id }
        if notes.isEmpty { notes = [QuickNote(text: "", modified: Date())] }
        if selectedID == id { selectedID = notes.first?.id }
        scheduleSave()
    }

    func copy(_ id: UUID) {
        guard let note = notes.first(where: { $0.id == id }) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.text, forType: .string)
    }

    /// Writes half a second after typing stops.
    private func scheduleSave() {
        saveWork?.cancel()
        let snapshot = notes
        let url = fileURL
        let work = DispatchWorkItem {
            if let data = try? JSONEncoder().encode(snapshot) { try? data.write(to: url, options: .atomic) }
        }
        saveWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5, execute: work)
    }
}

struct QuickNotesNotchView: View {
    var store: QuickNotesStore

    var body: some View {
        // Wide gap: macOS puts its Writing Tools button at the editor's top-left corner.
        HStack(alignment: .top, spacing: 22) {
            noteList
                .frame(width: 130)
            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var noteList: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Notes")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button { store.add() } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("New note")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(store.notes) { note in
                        Button { store.selectedID = note.id } label: {
                            Text(note.title)
                                .font(.system(size: 11, weight: note.id == store.selectedID ? .semibold : .regular))
                                .foregroundStyle(.white.opacity(note.id == store.selectedID ? 1 : 0.65))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(.white.opacity(note.id == store.selectedID ? 0.12 : 0))
                                )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Copy Text") { store.copy(note.id) }
                            Button("Delete", role: .destructive) { store.delete(note.id) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var editor: some View {
        if let note = store.selected {
            TextEditor(text: Binding(
                get: { store.selected?.text ?? "" },
                set: { store.update(note.id, text: $0) }
            ))
            .font(.system(size: 12))
            .foregroundStyle(.white)
            .scrollContentBackground(.hidden)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.06)))
            .overlay(alignment: .topLeading) {
                if note.text.isEmpty {
                    Text("Type a note…")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .allowsHitTesting(false)
                }
            }
            .id(note.id)
        }
    }
}
