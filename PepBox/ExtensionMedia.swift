//
//  ExtensionMedia.swift
//  PepBox
//
//  Extension icons and screenshots ship inside the app (ExtensionMedia/)
//  instead of being fetched from a website. They are referenced as
//  pepbox-media://icons/<file> or pepbox-media://images/<file>.
//

import Foundation

enum ExtensionMedia {
    static let scheme = "pepbox-media"

    /// Maps a pepbox-media:// URL to the bundled file; any other URL is returned unchanged
    static func resolve(_ url: URL) -> URL {
        guard url.scheme == scheme else { return url }
        let file = url.lastPathComponent as NSString
        let name = file.deletingPathExtension
        let ext = file.pathExtension
        return Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "ExtensionMedia")
            ?? Bundle.main.url(forResource: name, withExtension: ext)
            ?? url
    }
}
