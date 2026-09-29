// OpenSelectionBridge.swift
// DropClip
//
// Bridges OpenSelection to DropClip's internal Core domain types, logging pipeline,
// and backward-compatibility interfaces.
import AppKit
import Foundation
import DropClipCore
@_exported import OpenSelection

// Disambiguate types shared with Core in favor of Core domain types within DropClip.
public typealias AppIdentity = DropClipCore.AppIdentity
public typealias SelectionGatePolicy = DropClipCore.SelectionGatePolicy
public typealias CursorClass = DropClipCore.CursorClass
public typealias TextResult = DropClipCore.TextResult

extension SelectionRetrievalCoordinator {
    /// Convenience initializer preserving compatibility with DropClip's TextResult-based copy captures.
    public init(
        inspect: @escaping TargetProvider = { AXElementInspector.inspect() },
        copyCapture: (@Sendable (CopyTrigger) async -> DropClipCore.TextResult?)?,
        menuPress: @escaping MenuPress = SelectionRetrievalCoordinator.pressEditCopyMenu,
        scriptRunner: @escaping ScriptRunner = SelectionRetrievalCoordinator.defaultScriptRunner
    ) {
        let mappedCapture: CopyCapture? = copyCapture.map { cc in
            { @Sendable trigger in
                if let res = await cc(trigger) {
                    return OpenSelection.SelectionResult(
                        text: res.text,
                        bounds: res.bounds,
                        html: res.html,
                        rtf: res.rtf,
                        strategy: .keyboardCopy
                    )
                }
                return nil
            }
        }
        self.init(
            configuration: .default,
            inspect: inspect,
            copyCapture: mappedCapture,
            menuPress: menuPress,
            scriptRunner: scriptRunner
        )
    }

    /// Reads selection details using DropClip's DropClipCore.AppIdentity and DropClipCore.AppPolicyContext.
    public func retrieveDetails(
        for app: DropClipCore.AppIdentity,
        policy: DropClipCore.AppPolicyContext,
        cursor: DropClipCore.CursorClass,
        isSelectAll: Bool = false,
        allowCopyFallback: Bool = true,
        requireCopyEvidence: Bool = true
    ) async -> (result: DropClipCore.TextResult?, isEditable: Bool) {
        let openSelectionApp = OpenSelection.AppIdentity(bundleIdentifier: app.bundleIdentifier, localizedName: app.localizedName)
        let openSelectionPolicy = OpenSelection.SelectionPolicy(
            disabled: policy.disabled,
            hotkeyOnly: policy.hotkeyOnly,
            denyPaste: policy.denyPaste,
            useMenuCopy: policy.useMenuCopy,
            retrievalMode: OpenSelection.SelectionStrategy(rawValue: policy.retrievalMode.rawValue) ?? .axTextControl,
            gate: OpenSelection.SelectionGatePolicy(
                skipRoles: policy.gate.skipRoles,
                allowedCursors: Set(policy.gate.allowedCursors.compactMap { OpenSelection.CursorClass(rawValue: $0.rawValue) })
            )
        )
        let openSelectionCursor = OpenSelection.CursorClass(rawValue: cursor.rawValue) ?? .unknown

        let (result, isEditable) = await self.retrieveDetails(
            for: openSelectionApp,
            policy: openSelectionPolicy,
            cursor: openSelectionCursor,
            isSelectAll: isSelectAll,
            allowCopyFallback: allowCopyFallback,
            requireCopyEvidence: requireCopyEvidence
        )

        // `formattedText` performs WebKit-backed HTML import, which is main-actor isolated.
        let textResult: DropClipCore.TextResult?
        if let result {
            textResult = await MainActor.run {
                DropClipCore.TextResult(
                    text: result.formattedText,
                    bounds: result.bounds,
                    html: result.html,
                    rtf: result.rtf,
                    flavors: result.flavors.map { DropClipCore.RichPasteboardFlavor($0) }
                )
            }
        } else {
            textResult = nil
        }
        return (textResult, isEditable)
    }


    /// Reads selection using DropClip's DropClipCore.AppIdentity and DropClipCore.AppPolicyContext.
    public func retrieve(
        for app: DropClipCore.AppIdentity,
        policy: DropClipCore.AppPolicyContext,
        cursor: DropClipCore.CursorClass,
        isSelectAll: Bool = false,
        allowCopyFallback: Bool = true,
        requireCopyEvidence: Bool = true
    ) async -> DropClipCore.TextResult? {
        await retrieveDetails(
            for: app,
            policy: policy,
            cursor: cursor,
            isSelectAll: isSelectAll,
            allowCopyFallback: allowCopyFallback,
            requireCopyEvidence: requireCopyEvidence
        ).result
    }
}

extension DropClipCore.CursorClass {
    public var asOpenSelection: OpenSelection.CursorClass {
        OpenSelection.CursorClass(rawValue: self.rawValue) ?? .unknown
    }
}

extension OpenSelection.CursorClass {
    public var asCore: DropClipCore.CursorClass {
        DropClipCore.CursorClass(rawValue: self.rawValue) ?? .unknown
    }
}

extension DropClipCore.RichPasteboardFlavor {
    public init(_ flavor: PasteboardFlavor) {
        self.init(type: flavor.type, data: flavor.data)
    }
}

extension DropClipCore.TextResult {
    @MainActor
    public init(_ result: OpenSelection.SelectionResult) {
        self.init(
            text: result.formattedText,
            bounds: result.bounds,
            html: result.html,
            rtf: result.rtf,
            flavors: result.flavors.map { DropClipCore.RichPasteboardFlavor($0) }
        )
    }
}

extension OpenSelection.SelectionResult {
    @MainActor
    public var asTextResult: DropClipCore.TextResult {
        DropClipCore.TextResult(
            text: formattedText,
            bounds: bounds,
            html: html,
            rtf: rtf,
            flavors: flavors.map { DropClipCore.RichPasteboardFlavor($0) }
        )
    }
}

extension OpenSelection {
    /// Non-destructive or clipboard-copy paste replacement for DropClip effects.
    @MainActor
    public static func replace(
        with text: String,
        html: String? = nil,
        rtf: String? = nil,
        flavors: [PasteboardFlavor] = [],
        in app: NSRunningApplication? = nil,
        matchStyle: Bool = false,
        pasteboard: NSPasteboard = .general,
        restoreDelay: TimeInterval = 0.25,
        restorePasteboard: Bool = true,
        keyPoster: (@MainActor @Sendable (CGKeyCode, CGEventFlags) -> Void)? = nil
    ) async throws {
        let config = SelectionConfiguration(
            pasteboardDeliveryRestoreDelay: restoreDelay,
            pasteVirtualKey: Constants.vVirtualKey
        )
        let replacer = SelectionReplacer(
            configuration: config,
            pasteboard: pasteboard,
            directAXReplacer: { _, _ in false },
            keyPoster: keyPoster ?? { KeyboardEventPoster.postKey(keyCode: $0, flags: $1) }
        )
        try await replacer.replace(
            with: text,
            html: html,
            rtf: rtf,
            flavors: flavors,
            in: app,
            matchStyle: matchStyle,
            restorePasteboard: restorePasteboard
        )
    }
}

