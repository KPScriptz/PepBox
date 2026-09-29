//
//  DropClipActionsFormList.swift
//  DropClip, inside Droppy
//
//  The Actions page as rows of Droppy's grouped Form. Upstream's page is an
//  NSOutlineView with row views of its own: big switches first, chevrons
//  last, full-width separators and a hover highlight no Settings row has.
//  Here every action is the row System Settings draws for something that
//  can be switched on and opened (`DropClipSwitchRow`): its icon and name,
//  the info button that opens its page, and the Form's own switch. A group
//  (a custom group, an extension's commands, the AI tools) opens its members
//  under it with the disclosure at its leading edge. Rows are put in order
//  by dragging, as before; the harness keeps upstream's outline.
//

import DropClipCore
import SwiftUI

@MainActor
struct DropClipActionsFormList: View {
    @Binding var disabledActionIDs: Set<String>
    @Binding var disabledPackages: Set<String>
    /// The page's search.
    let query: String
    /// The search, as a field at the top of the page, where the toolbar cannot hold it
    /// (`DropClipHost.pageSearchInToolbar`); `nil` when it is the toolbar's.
    var inlineSearch: Binding<String>? = nil

    @ObservedObject private var coordinator = ActionCoordinator.shared
    @ObservedObject private var customization = ActionCustomizationManager.shared
    @ObservedObject private var bindingStore = ActionBindingStore.shared
    // Not `CustomIconManager`: nothing here reads it, and observing it rebuilt the whole list on
    // every custom icon rescan.
    @ObservedObject private var ai = AIServiceManager.shared

    @State private var expandedGroupIDs: Set<String> = []

    /// One row of the list: a top-level entry, or a member of an open group.
    private struct Row {
        let node: OutlineNode
        let isMember: Bool
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let _ = DropClipActionsListPasses.note()
        let roots = ActionsOutlineCoordinator.buildTree(
            actions: coordinator.actions,
            groupDefs: coordinator.actionGroupDefs,
            query: query,
            customization: customization
        )
        let rows = flatten(roots)
        let rowsByID = Dictionary(rows.map { ($0.node.id, $0) }, uniquingKeysWith: { first, _ in first })

        DropClipSettingsPageBody {
            // A section of its own, above the list's: the rows a drag counts stay the list's, and
            // the field stays where it is while the rows under it change with each letter typed.
            if let inlineSearch {
                Section {
                    DropClipSearchRow(text: inlineSearch, prompt: String(localized: "Search actions"))
                }
            }

            Section {
                if rows.isEmpty {
                    Text("No actions match \u{201C}\(query)\u{201D}.")
                        .foregroundStyle(.secondary)
                } else {
                    DropClipReorderableFormRows(
                        ids: rows.map(\.node.id),
                        canDrag: { id in
                            // Searching reorders nothing; a member keeps its group's order,
                            // which its group's page sets; a header is not an action.
                            guard !isSearching, let row = rowsByID[id], !row.isMember else { return false }
                            if case .packageHeader = row.node.kind { return false }
                            return true
                        },
                        dragPreviewTitle: { id in
                            rowsByID[id].flatMap { title(of: $0.node) } ?? id
                        },
                        onMove: { id, gap in
                            // Only top-level rows move: count the ones above the gap.
                            let rootIndex = rows.prefix(gap).filter { !$0.isMember }.count
                            ActionsOutlineCoordinator.moveRoots([id], toRootIndex: rootIndex, roots: roots, coordinator: coordinator)
                        }
                    ) { id in
                        if let row = rowsByID[id] {
                            rowView(row)
                        }
                    }
                }
            } header: {
                settingsNote("The popup bar, in order. Drag a row to move it.")
            } footer: {
                settingsNote("Turn off an action to hide it. Set an alias or a hotkey on its page.")
                    .padding(.top, 6)
            }
        }
    }

    // MARK: - Rows

    private func flatten(_ roots: [OutlineNode]) -> [Row] {
        var rows: [Row] = []
        // Each id once, first one kept: the Form's rows are keyed by id, and a drag's gap counts
        // these same rows (`DropClipReorderableFormRows` drops repeats the same way).
        var seen = Set<String>()
        func append(_ row: Row) {
            if seen.insert(row.node.id).inserted { rows.append(row) }
        }
        for node in roots {
            append(Row(node: node, isMember: false))
            // While searching every group is open, as the outline opened them.
            if node.isGroup, isSearching || expandedGroupIDs.contains(node.id) {
                for child in node.children {
                    append(Row(node: child, isMember: true))
                }
            }
        }
        return rows
    }

    @ViewBuilder
    private func rowView(_ row: Row) -> some View {
        switch row.node.kind {
        case .packageHeader(let packageID, let title, let gatedReason):
            DropClipSwitchRow(
                isOn: ActionEnablement.packageBinding(
                    packageID: packageID,
                    gatedReason: gatedReason,
                    disabledPackages: $disabledPackages
                ),
                infoTitle: String(localized: "Configure Extension"),
                onInfo: { SettingsRouter.shared.show(path: SettingsDestination.path(forPackage: packageID)) }
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "shippingbox")
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                    DropClipRowTitle(title: title, subtitle: gatedReason.flatMap(extensionGateDescription(for:)))
                }
            }
        case .customGroup(_, let action), .extensionGroup(let action),
             .standaloneAction(let action), .groupMember(let action, _),
             .extensionSubAction(let action, _):
            actionRow(action, node: row.node, isMember: row.isMember)
        }
    }

    private func actionRow(_ action: any Action, node: OutlineNode, isMember: Bool) -> some View {
        let presentation = customization.presented(action, surface: .table)
        let isGroup = node.isGroup && !node.children.isEmpty
        return DropClipSwitchRow(
            isOn: ActionEnablement.binding(
                for: action,
                disabledActionIDs: $disabledActionIDs,
                disabledPackages: $disabledPackages
            ),
            infoTitle: String(localized: "Configure Action"),
            onInfo: { open(node, action: action) }
        ) {
            HStack(spacing: 8) {
                if isGroup {
                    disclosure(for: node)
                } else if isMember {
                    // A member sits one step in, under its group's name.
                    Color.clear.frame(width: 14)
                }
                ActionIconView(icon: presentation.icon, size: 14)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.secondary)
                DropClipRowTitle(
                    title: presentation.title,
                    subtitle: isGroup ? memberCount(node.children.count) : gateNote(for: action)
                )
            }
        }
    }

    private func disclosure(for node: OutlineNode) -> some View {
        let isOpen = isSearching || expandedGroupIDs.contains(node.id)
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                if expandedGroupIDs.contains(node.id) {
                    expandedGroupIDs.remove(node.id)
                } else {
                    expandedGroupIDs.insert(node.id)
                }
            }
        } label: {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isOpen ? 90 : 0))
                .frame(width: 14, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSearching)
        .accessibilityLabel(Text(isOpen ? "Collapse" : "Expand"))
    }

    private func open(_ node: OutlineNode, action: any Action) {
        if case .customGroup = node.kind {
            SettingsRouter.shared.push(.action(id: node.id))
        } else {
            SettingsDestination.open(action)
        }
    }

    private func title(of node: OutlineNode) -> String? {
        if case .packageHeader(_, let title, _) = node.kind { return title }
        guard let action = node.action else { return nil }
        return customization.presented(action, surface: .table).title
    }

    private func memberCount(_ count: Int) -> String {
        count == 1 ? String(localized: "1 action") : String(localized: "\(count) actions")
    }

    private func gateNote(for action: any Action) -> String? {
        guard let gated = action as? GatedExtensionAction else { return nil }
        return extensionGateDescription(for: gated.reason)
    }

    private func settingsNote(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// How often the Actions list is drawn, in Droppy's log (a notice, which the system keeps): its
/// first pass, then the passes of each stretch of at least five seconds in which it was drawn
/// again. A page that settles is drawn a few times as it opens and once per letter typed; one that
/// never settles is drawn thousands of times a stretch, which a user's log shows where the freeze
/// cannot be reproduced.
@MainActor
enum DropClipActionsListPasses {
    private static var count = 0
    private static var since: TimeInterval?

    static func note() {
        count += 1
        let now = ProcessInfo.processInfo.systemUptime
        if let since, now - since < 5 { return }
        let stretch = since.map { " in \(Int(now - $0)) s" } ?? ""
        Log.selection.debug("Actions list passes: \(count)\(stretch, privacy: .public)")
        count = 0
        since = now
    }
}
