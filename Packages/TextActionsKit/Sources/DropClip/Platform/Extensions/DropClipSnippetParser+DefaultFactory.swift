// DropClipSnippetParser+DefaultFactory.swift
// DropClip
//
// Extends DropClipSnippetParser with convenience factory methods for creating actions directly from snippet files.
import Foundation
import DropClipCore

extension DropClipSnippetParser {
    public static func parse(snippet: String) async -> (any Action)? {
        return await parse(snippet: snippet, factory: DefaultActionFactory())
    }
}
