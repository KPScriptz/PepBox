// DefaultCustomActionJSRunner.swift
// DropClip
//
// Implements CustomActionJSRunning for JavaScript CustomActions by delegating to DropClipJSHost.
// Kept in the DropClip target so Core stays free of JavaScriptCore and platform side effects.

import Foundation
import DropClipCore

@MainActor
public struct DefaultCustomActionJSRunner: CustomActionJSRunning {
    public init() {}

    public func run(
        script: String,
        isAsync: Bool,
        replaceSelection: Bool,
        context: ActionContext,
        actionID: String
    ) async throws -> ActionResult {
        let request = DropClipJSHost.Request(
            actionID: actionID,
            scriptCode: script,
            context: context,
            options: [],
            optionStore: SettingsActionOptionStore(),
            rules: ExtensionActionRules(),
            isAsync: isAsync,
            timeout: Constants.scriptTimeout,
            packageDirectory: nil,
            entryDirectory: nil,
            pasteboardContent: DropClipJSHost.PasteboardContent.read()
        )
        return try await DropClipJSHost().run(request)
    }
}
