//
//  DropClipNativeSettings.swift
//  DropClip, inside Droppy
//
//  DropClip's settings in Droppy's native look: grouped Form pages, Droppy's
//  own rows, system buttons. Upstream's own look stays for the harness.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Strings

/// DropClip's text in Droppy's language, as a `String`, for DroppyKit's rows (which take strings).
///
/// Every string DropClip shows is in Droppy's catalog, which is the table `Bundle.main` reads in
/// a droplet, so a lookup there is the translation the rest of Droppy uses too.
enum DropClipLocalized {
    /// The text a `LocalizedStringKey` literal says. DropClip's settings rows are all built from
    /// literals, whose key is the English text itself.
    static func string(_ key: LocalizedStringKey) -> String {
        let key = Mirror(reflecting: key).children.first { $0.label == "key" }?.value as? String ?? ""
        return string(key)
    }

    /// Longer than any label, so a long selection is never hashed on every render only to miss.
    private static let longestKey = 400

    static func string<S: StringProtocol>(_ text: S) -> String {
        let key = String(text)
        guard !key.isEmpty, key.utf16.count <= longestKey else { return key }
        return Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }
}

// MARK: - Pages

/// One of DropClip's settings pages. Inside Droppy it is a page of Droppy's own Settings: a
/// grouped Form (DroppyKit's `DropletSettingsPage`), where DropClip's cards are Form sections and
/// its rows are Droppy's rows. Outside Droppy it is upstream's scrolling stack of cards.
struct DropClipSettingsPageBody<Content: View>: View {
    var spacing: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        // PepBox: always upstream's scrolling stack of cards (Droppy's Form needs DroppyKit).
        ScrollView {
            VStack(spacing: spacing) {
                content()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
    }
}

/// A group of cards that sits inside a page. Upstream stacks them in a `VStack`; inside a Form a
/// stack is one row, so inside Droppy the cards join the page's Form as sections of their own.
struct DropClipSettingsGroup<Content: View>: View {
    var spacing: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        // PepBox: Droppy-only branch removed
        VStack(spacing: spacing) { content() }
        
    }
}

extension View {
    /// A Form DropClip builds itself (AI, custom actions, an extension's page): inside Droppy it
    /// shows the Form's own background, as Droppy's pages do, and its DropClip rows draw Droppy's
    /// native rows.
    @ViewBuilder
    func dropClipNativeForm() -> some View {
        // PepBox: upstream's look (Droppy's native Form rows need DroppyKit).
        self.scrollContentBackground(.hidden)
    }
}

// MARK: - Controls

extension View {
    /// A row control upstream pins to a fixed width. Inside Droppy it takes its own size, so the
    /// Form sets it on the row's trailing edge like every other control: a fixed frame centres a
    /// narrower control (three glyph segments) short of that edge and lets a wider one (three
    /// words) spill past it, so neighbouring rows never lined up.
    @ViewBuilder
    func dropClipControlWidth(_ width: CGFloat, height: CGFloat? = nil) -> some View {
        // PepBox: Droppy-only branch removed
        self.frame(width: width, height: height)
        
    }

    /// A switch upstream sizes itself (a page's hero). Inside Droppy it is the size of every other
    /// switch on the page, the grouped Form's own: mini on macOS 26 and later, small before.
    @ViewBuilder
    func dropClipFormSwitchSize(upstream: ControlSize) -> some View {
        // PepBox: Droppy-only branch removed
        self.controlSize(upstream)
        
    }

    /// A text field upstream draws by hand (plain field on a tinted rounded rectangle). Inside
    /// Droppy it is the system's own rounded field. Apply to the `TextField` itself, with
    /// upstream's chain in `upstream`.
    @ViewBuilder
    func dropClipNativeTextField<Upstream: View>(@ViewBuilder _ upstream: (Self) -> Upstream) -> some View {
        // PepBox: Droppy-only branch removed
        upstream(self)
        
    }
}

// MARK: - Buttons

extension View {
    /// Upstream's text button on a Liquid Glass capsule. Inside Droppy it is the system's bordered
    /// button, the one every Settings row in Droppy uses. Apply to the `Button` itself.
    @ViewBuilder
    func dropClipCapsuleButton(
        tint: Color? = nil,
        fontSize: CGFloat = 11.5,
        height: CGFloat = 24,
        foreground: Color? = nil
    ) -> some View {
        // PepBox: Droppy-only branch removed
        self
                .buttonStyle(.plain)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(foreground ?? SettingsDesignTokens.primaryText)
                .padding(.horizontal, 10)
                .frame(height: height)
                .settingsGlassCapsule(tint: tint)
                .contentShape(Capsule())
        
    }

    /// A `Button` in upstream's own chain outside Droppy, and the system's bordered button inside,
    /// for a chain the capsule helper does not cover (a secondary ink, other padding).
    @ViewBuilder
    func dropClipNativeButton<Upstream: View>(@ViewBuilder _ upstream: (Self) -> Upstream) -> some View {
        // PepBox: Droppy-only branch removed
        upstream(self)
        
    }

    /// A `Button` whose label wears upstream's glass capsule: the label as it is outside Droppy,
    /// and inside Droppy the label bare and the button the system's bordered one. Apply
    /// `dropClipGlassLabel` to the label and this to the button.
    @ViewBuilder
    func dropClipLabelButtonStyle() -> some View {
        // PepBox: Droppy-only branch removed
        self.buttonStyle(.plain)
        
    }

    /// Upstream's glass capsule behind a button's label, outside Droppy only.
    @ViewBuilder
    func dropClipGlassLabel(tint: Color? = nil, horizontalPadding: CGFloat = 10, height: CGFloat? = 24) -> some View {
        // PepBox: Droppy-only branch removed
        self
                .padding(.horizontal, horizontalPadding)
                .frame(height: height)
                .settingsGlassCapsule(tint: tint)
                .contentShape(Capsule())
        
    }

    /// Upstream's glass chip behind a suggestion's label, outside Droppy only.
    @ViewBuilder
    func dropClipChipLabel() -> some View {
        // PepBox: Droppy-only branch removed
        self
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .settingsGlassCapsule()
                .contentShape(Capsule())
        
    }

    /// Upstream's icon button on a Liquid Glass circle. Inside Droppy it is the system's borderless
    /// icon button. Apply to the `Button` itself.
    @ViewBuilder
    func dropClipCircleButton(tint: Color? = nil) -> some View {
        // PepBox: Droppy-only branch removed
        self
                .buttonStyle(.plain)
                .settingsGlassCircle(tint: tint)
                .contentShape(Circle())
        
    }
}

// MARK: - Rows

/// Something that can be switched on and opened, as a row of Droppy's Form, the way System
/// Settings lists one (Sharing, Login Items): what it is on the left, then the info button that
/// opens it and the Form's own switch on the right, aligned to the first line. Upstream's rows
/// put a small switch first and a chevron last, which no row in Droppy does; inside a Form that
/// switch also came out bigger than every other switch on the page.
///
/// `accessory` sits between the label and the info button (an action's alias field).
struct DropClipSwitchRow<Label: View, Accessory: View>: View {
    @Binding var isOn: Bool
    /// What the info button opens, for its tooltip and VoiceOver: "Edit action prompt".
    let infoTitle: String
    let onInfo: @MainActor () -> Void
    @ViewBuilder var label: () -> Label
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        // A top-level Toggle with the label inside it: what the grouped Form gives its mini
        // switch to, trailing and on the title's first line.
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                label()
                    .layoutPriority(1)
                Spacer(minLength: 8)
                accessory()
                Button {
                    onInfo()
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help(infoTitle)
                .accessibilityLabel(Text(infoTitle))
            }
        }
    }
}

extension DropClipSwitchRow where Accessory == EmptyView {
    init(
        isOn: Binding<Bool>,
        infoTitle: String,
        onInfo: @escaping @MainActor () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.init(isOn: isOn, infoTitle: infoTitle, onInfo: onInfo, label: label, accessory: { EmptyView() })
    }
}

/// A template or a script as a row of Droppy's Form: the system's multi-line field, in a
/// monospaced face, growing with what it holds. The shape of Droppy's own snippet page.
struct DropClipCodeField: View {
    let title: LocalizedStringKey
    @Binding var text: String

    init(_ title: LocalizedStringKey, text: Binding<String>) {
        self.title = title
        self._text = text
    }

    var body: some View {
        TextField(title, text: $text, axis: .vertical)
            .font(.system(.body, design: .monospaced))
            .lineLimit(4...14)
    }
}

/// A row's title over a secondary line, as the Form draws a row with a subtitle.
struct DropClipRowTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .lineLimit(1)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}

/// A page's search as a row of Droppy's Form: the system's search field across the row, with its
/// magnifier, clear button and Escape. For a Droppy whose toolbar cannot hold the page's search
/// (`DropClipHost.pageSearchInToolbar`); its own height, like every other field in the Form.
struct DropClipSearchRow: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        NativeSearchField(text: $text, placeholder: prompt, acceptsDrops: false)
            .accessibilityLabel(Text(prompt))
    }
}

/// Rows of Droppy's Form put in order by dragging them, with the insertion bar drawn in the gap
/// the drag is over.
///
/// Upstream's `ReorderableRows` stacks its rows in a `VStack` with dividers of its own, which
/// inside a grouped Form is ONE row: the Form's insets went around the whole list rather than
/// each row, so the first row sat lower than the others and the separators were not the Form's
/// (the AI actions page, Jordy, 2026-09-25). Here each id is a row of the Form, with the Form's
/// own padding and separators, and each row takes the drop for the gap above or below its middle.
/// The rule is upstream's: a drop lands between rows, never on one.
@MainActor
struct DropClipReorderableFormRows<Row: View>: View {
    let ids: [String]
    /// Rows that stay put (a header, a group's member) still take drops for the gaps around
    /// them, so the bar can land anywhere; only the rows this allows can be picked up.
    var canDrag: (String) -> Bool = { _ in true }
    let dragPreviewTitle: (String) -> String
    /// The dragged row and the gap it was dropped into: 0 is above the first row, the number of
    /// rows below the last. Rows are `ids` without repeats (see `uniqueIDs`).
    let onMove: (String, Int) -> Void
    @ViewBuilder let row: (String) -> Row

    @State private var draggingID: String?
    @State private var insertionGap: Int?
    /// The row whose drop target last set `insertionGap`, so a row the drag leaves only clears
    /// the bar it drew, not the one the next row just set.
    @State private var gapOwner: String?
    /// Each row's measured height, which only a drag over the row reads.
    ///
    /// Kept in a plain class nothing observes; the `@State` only holds on to the one instance and
    /// is never assigned. The heights used to be a `@State` dictionary that `body` read back for
    /// every row's drop delegate, so each row's first layout, and every row that scrolled in or
    /// appeared when a group opened, re-rendered every row of the Form. With many actions that
    /// kept Droppy's main thread busy until the Actions page stopped scrolling and Droppy stopped
    /// responding (Trench a749f41a), and opening AI tools stuttered while its rows reported in
    /// (058ff760). Now a measurement lands here and nothing redraws.
    @State private var heightLedger = DropClipRowHeightLedger()

    /// `ids` without repeats, first one kept. `ForEach` needs every id once; a repeated id (a
    /// member listed twice, carried-over data) is undefined behaviour there.
    private var uniqueIDs: [String] {
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }

    var body: some View {
        let rowIDs = uniqueIDs
        let ledger = heightLedger
        ForEach(Array(rowIDs.enumerated()), id: \.element) { index, id in
            row(id)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    ledger.heights[id] = height
                }
                .modifier(DropClipRowDragSource(
                    isEnabled: canDrag(id),
                    title: dragPreviewTitle(id),
                    onStart: { draggingID = id },
                    provider: { NSItemProvider(object: id as NSString) }
                ))
                .onDrop(of: [.text], delegate: DropClipFormRowDropDelegate(
                    index: index,
                    rowID: id,
                    heightLedger: ledger,
                    isDraggingActive: { draggingID != nil },
                    onGapChanged: { gap in
                        // A drag reports on every move; only a new gap is worth a redraw.
                        if insertionGap != gap { insertionGap = gap }
                        if gapOwner != id { gapOwner = id }
                    },
                    onExited: {
                        guard gapOwner == id else { return }
                        insertionGap = nil
                        gapOwner = nil
                    },
                    onDrop: { gap in
                        defer {
                            insertionGap = nil
                            gapOwner = nil
                            draggingID = nil
                        }
                        guard let draggingID else { return false }
                        onMove(draggingID, gap)
                        return true
                    }
                ))
                .overlay(alignment: .top) {
                    if insertionGap == index {
                        insertionBar.offset(y: -Self.barOffset)
                    }
                }
                .overlay(alignment: .bottom) {
                    if insertionGap == rowIDs.count, index == rowIDs.count - 1 {
                        insertionBar.offset(y: Self.barOffset)
                    }
                }
        }
    }

    /// From the row's content to the line between two rows: the Form's vertical row padding,
    /// less half the bar.
    private static var barOffset: CGFloat {
        // PepBox: a Form row's vertical padding (was DroppyKit's DroppySettingsLayoutMetrics).
        7 - 1
    }

    private var insertionBar: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
    }
}

/// A row that can be picked up, or one that cannot.
private struct DropClipRowDragSource: ViewModifier {
    let isEnabled: Bool
    let title: String
    let onStart: () -> Void
    let provider: () -> NSItemProvider

    func body(content: Content) -> some View {
        if isEnabled {
            content.onDrag {
                onStart()
                return provider()
            } preview: {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .padding(6)
            }
        } else {
            content
        }
    }
}

/// The measured height of each row of a `DropClipReorderableFormRows`, by id.
///
/// Deliberately not `ObservableObject` and not `@Observable`: writing a height must never
/// invalidate a view (see `DropClipReorderableFormRows.heightLedger`).
@MainActor
final class DropClipRowHeightLedger {
    var heights: [String: CGFloat] = [:]
}

/// One row's share of the drop: the gap above its middle or below it.
@MainActor
private struct DropClipFormRowDropDelegate: DropDelegate {
    let index: Int
    let rowID: String
    /// Read while a drag is over the row, never while the list draws.
    let heightLedger: DropClipRowHeightLedger
    let isDraggingActive: () -> Bool
    let onGapChanged: (Int) -> Void
    let onExited: () -> Void
    let onDrop: (Int) -> Bool

    private func gap(_ info: DropInfo) -> Int {
        let height = heightLedger.heights[rowID] ?? 0
        return info.location.y > height / 2 ? index + 1 : index
    }

    func dropEntered(info: DropInfo) {
        guard isDraggingActive() else { return }
        onGapChanged(gap(info))
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard isDraggingActive() else { return nil }
        onGapChanged(gap(info))
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        onExited()
    }

    func performDrop(info: DropInfo) -> Bool {
        guard isDraggingActive() else { return false }
        return onDrop(gap(info))
    }
}
