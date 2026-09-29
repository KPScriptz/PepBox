//
//  DropClipAssets.swift
//  DropClip, inside Droppy
//
//  The images upstream keeps in its asset catalog and Resources, shipped as
//  files in `Assets/Images`.
//

import AppKit
import DropClipCore
import SwiftUI

/// A droplet bundle carries no compiled catalog of its own, and a named lookup against Droppy's
/// finds nothing, so DropClip's own images ship as files (`Assets/Images`, published by the
/// droplet build into the bundle's resources).
enum DropClipAssets {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: NSImage] = [:]

    static func image(named name: String) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[name] { return cached }
        for ext in ["svg", "png", "pdf"] {
            guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Assets/Images"),
                  let image = NSImage(contentsOf: url)
            else { continue }
            cache[name] = image
            return image
        }
        return nil
    }
}

extension Image {
    /// `Image(name)` for one of DropClip's own images.
    static func dropClipAsset(_ name: String) -> Image {
        if let image = DropClipAssets.image(named: name) { return Image(nsImage: image) }
        return Image(name)
    }
}
