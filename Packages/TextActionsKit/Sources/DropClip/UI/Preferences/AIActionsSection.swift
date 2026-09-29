// AIActionsSection.swift
// DropClip
//
// The AI prompt library as a `Section` of the AI page: `ReorderableRows`, the same drag-into-order
// list the group editor uses, with each row a way into that prompt's page. This used to be a
// sub-tab of a 440x480 popover, and editing a preset opened a `.sheet` from inside that popover —
// three layers, to change two text fields.

import SwiftUI

@MainActor
public struct AIActionsSection: View {
    @ObservedObject private var aiManager = AIServiceManager.shared
    @ObservedObject private var router = SettingsRouter.shared

    public init() {}

    public var body: some View {
        // PepBox: Droppy-only branch removed
        upstreamBody
        
    }

    /// Droppy: every prompt a row of Droppy's Form (`DropClipReorderableFormRows`), drawn the way
    /// System Settings lists what can be switched on and opened (`DropClipSwitchRow`): the title
    /// over its prompt, then the info button that opens the prompt's page and the Form's switch.
    /// Dragging a row still puts it in order. A new prompt is the "New AI action" pill in Droppy's
    /// toolbar (`DropClipPageToolbar`), so the list carries no row for it, and Reset defaults is
    /// the system's button under the card rather than a link in the header.
    private var droppyBody: some View {
        Section {
            DropClipReorderableFormRows(
                ids: aiManager.presets.map(\.id),
                dragPreviewTitle: { id in aiManager.presets.first(where: { $0.id == id })?.title ?? id },
                onMove: { id, gap in aiManager.movePreset(id: id, toGap: gap) }
            ) { id in
                if let preset = aiManager.presets.first(where: { $0.id == id }) {
                    DropClipSwitchRow(
                        isOn: enabledBinding(preset),
                        infoTitle: String(localized: "Edit Action Prompt"),
                        onInfo: { router.push(.aiPreset(id: preset.id)) }
                    ) {
                        DropClipRowTitle(title: preset.title, subtitle: preset.prompt)
                    }
                }
            }
        } header: {
            Text("AI Actions")
        } footer: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("These appear inside the AI Tools group in the popup bar. Drag to reorder.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Button("Reset Defaults") {
                    aiManager.resetPresetsToDefault()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 10)
            .padding(.trailing, -10)
        }
        .disabled(!aiManager.isAIEnabled)
    }

    private func enabledBinding(_ preset: AIActionPreset) -> Binding<Bool> {
        Binding(
            get: { preset.isEnabled },
            set: { newValue in
                var updated = preset
                updated.isEnabled = newValue
                aiManager.updatePreset(updated)
            }
        )
    }

    private var upstreamBody: some View {
        Section {
            ReorderableRows(
                ids: aiManager.presets.map(\.id),
                dragPreviewTitle: { id in aiManager.presets.first(where: { $0.id == id })?.title ?? id },
                onMove: { id, gap in aiManager.movePreset(id: id, toGap: gap) }
            ) { id in
                if let preset = aiManager.presets.first(where: { $0.id == id }) {
                    row(preset)
                }
            }

            SettingsDisclosureRow {
                router.push(.aiNewPreset)
            } content: {
                Label("Add Custom AI Action", systemImage: "plus.circle")
                    .foregroundStyle(Color.accentColor)
            }
        } header: {
            HStack {
                Text("AI Actions")
                Spacer()
                Button("Reset Defaults") {
                    aiManager.resetPresetsToDefault()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        } footer: {
            Text("These appear inside the AI Tools group in the popup bar. Drag to reorder.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(!aiManager.isAIEnabled)
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(_ preset: AIActionPreset) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Toggle("", isOn: Binding(
                get: { preset.isEnabled },
                set: { newValue in
                    var updated = preset
                    updated.isEnabled = newValue
                    aiManager.updatePreset(updated)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityLabel(String(localized: "Enable \(preset.title)"))

            // The rest of the row drills into the prompt: the row is the control, the way a
            // System Settings list row is.
            Button {
                router.push(.aiPreset(id: preset.id))
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.title)
                            .font(.system(size: 13, weight: .medium))
                        Text(preset.prompt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Edit Action Prompt")
        }
        .padding(.vertical, 6)
    }
}
