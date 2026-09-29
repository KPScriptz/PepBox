// NativeSearchField.swift
// DropClip
//
// A real `NSSearchField` for the places that need a search box inline in the
// content rather than in the toolbar (the toolbar ones use `.searchable`).
// Wrapping AppKit's control keeps the magnifier, the recents menu, the cancel
// button, the focus ring and the vibrancy behaviour the system already ships.
import AppKit
import SwiftUI

struct NativeSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var controlSize: NSControl.ControlSize = .regular
    var focusRingType: NSFocusRingType = .default
    /// Droppy: false above a list whose rows are dragged as text, so a drag that overshoots the
    /// top slot cannot drop an action id into the search.
    var acceptsDrops = true
    /// Called when the user presses Return; searches that are too expensive to
    /// run per keystroke (the Iconify catalog) hang off this instead of `text`.
    var onSubmit: ((String) -> Void)?

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.controlSize = controlSize
        field.bezelStyle = .roundedBezel
        field.focusRingType = focusRingType
        field.font = .systemFont(ofSize: NSFont.systemFontSize(for: controlSize))
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.searchFieldDidSubmit(_:))
        field.sendsWholeSearchString = onSubmit != nil
        field.sendsSearchStringImmediately = onSubmit == nil
        if !acceptsDrops { field.unregisterDraggedTypes() }
        return field
    }

    /// Droppy: only what changed, since an inline field is updated on every keystroke and each
    /// assignment can invalidate its size and re-measure the row it sits in.
    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        if field.placeholderString != placeholder { field.placeholderString = placeholder }
        if field.controlSize != controlSize { field.controlSize = controlSize }
        if field.focusRingType != focusRingType { field.focusRingType = focusRingType }
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    /// Droppy: the width it is offered (180 when asked for its own) and the field's own height.
    /// Left to SwiftUI, the field is measured through `fittingSize`, a layout pass of its own on
    /// every measurement, which a row of Droppy's Form repeats on every pass of the page.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView field: NSSearchField, context: Context) -> CGSize? {
        let height = field.intrinsicContentSize.height
        return CGSize(width: proposal.width ?? 180, height: height > 0 ? height : 22)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: NativeSearchField

        init(parent: NativeSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        @objc func searchFieldDidSubmit(_ sender: NSSearchField) {
            parent.text = sender.stringValue
            parent.onSubmit?(sender.stringValue)
        }
    }
}
