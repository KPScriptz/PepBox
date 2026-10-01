//
//  DropClipLocalizedText.swift
//  DropClip, inside Droppy
//
//  DropClip's words in Droppy's language.
//
//  DropClip looks its literals up (`Text("…")`, `String(localized:)`), but it
//  names much of what it shows in a `String` (an action's name, a row's title,
//  a tooltip), which SwiftUI draws verbatim. Inside Droppy both go through
//  Droppy's own string catalog, which carries DropClip's words in every
//  language Droppy ships.
//
//  The overloads below have SwiftUI's own signatures, so inside this module
//  they shadow SwiftUI's verbatim initializers and modifiers: DropClip's
//  sources stay upstream's, and a `String` passed to any of them is looked up
//  first. A string the catalog does not know (a file name, an app's name, the
//  selected text) comes back unchanged. `Text(verbatim:)` stays verbatim.
//

import Foundation
import SwiftUI

extension Text {
    @_disfavoredOverload
    nonisolated init<S: StringProtocol>(_ content: S) {
        self.init(verbatim: DropClipLocalized.string(content))
    }

    @_disfavoredOverload
    nonisolated func accessibilityLabel<S: StringProtocol>(_ label: S) -> Text {
        accessibilityLabel(Text(verbatim: DropClipLocalized.string(label)))
    }
}

extension Button where Label == Text {
    @_disfavoredOverload
    @preconcurrency nonisolated init<S: StringProtocol>(_ title: S, action: @escaping () -> Void) {
        self.init(action: action) { Text(verbatim: DropClipLocalized.string(title)) }
    }
}

extension Label where Title == Text, Icon == Image {
    @_disfavoredOverload
    nonisolated init<S: StringProtocol>(_ title: S, systemImage name: String) {
        self.init {
            Text(verbatim: DropClipLocalized.string(title))
        } icon: {
            Image(systemName: name)
        }
    }
}

extension Toggle where Label == Text {
    @_disfavoredOverload
    nonisolated init<S: StringProtocol>(_ title: S, isOn: Binding<Bool>) {
        self.init(isOn: isOn) { Text(verbatim: DropClipLocalized.string(title)) }
    }
}

extension TextField where Label == Text {
    @_disfavoredOverload
    nonisolated init<S: StringProtocol>(_ title: S, text: Binding<String>) {
        let title = DropClipLocalized.string(title)
        self.init(text: text, prompt: Text(verbatim: title)) { Text(verbatim: title) }
    }
}

extension Section where Parent == Text, Footer == EmptyView, Content: View {
    @_disfavoredOverload
    init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {
        self.init(content: content) { Text(verbatim: DropClipLocalized.string(title)) }
    }
}

extension LabeledContent where Label == Text, Content: View {
    @_disfavoredOverload
    init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {
        self.init(content: content) { Text(verbatim: DropClipLocalized.string(title)) }
    }
}

extension View {
    /// Not `@_disfavoredOverload`, unlike the rest: SwiftUI's returns an
    /// opaque type, which no overload here can repeat, so this one wins on
    /// ranking instead of shadowing. A literal lands here too, and is looked
    /// up the same way.
    nonisolated func help(_ text: String) -> some View {
        help(Text(verbatim: DropClipLocalized.string(text)))
    }

    @_disfavoredOverload
    nonisolated func accessibilityLabel<S: StringProtocol>(_ label: S) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityLabel(Text(verbatim: DropClipLocalized.string(label)))
    }

    @_disfavoredOverload
    nonisolated func accessibilityHint<S: StringProtocol>(_ hint: S) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityHint(Text(verbatim: DropClipLocalized.string(hint)))
    }

    nonisolated func navigationTitle(_ title: String) -> some View {
        navigationTitle(Text(verbatim: DropClipLocalized.string(title)))
    }
}
