//
//  SVGImageDecoding.swift
//  DropClip, inside Droppy
//
//  The one call DropClip makes into SDWebImageSVGCoder, answered by AppKit.
//

import AppKit

/// Droppy: DropClip decodes SVG icons with `SDImageSVGCoder.shared.decodedImage(with:options:)`.
/// A droplet links DroppyKit and nothing else (the port from OpenClip (PROVENANCE.md) drops the import), and
/// AppKit reads SVG itself (`NSImage(data:)` hands back an SVG image rep), so this is that.
final class SDImageSVGCoder: @unchecked Sendable {
    static let shared = SDImageSVGCoder()

    func decodedImage(with data: Data?, options: [String: Any]?) -> NSImage? {
        guard let data, !data.isEmpty else { return nil }
        return NSImage(data: data)
    }

    /// An icon drawn once into a bitmap `pointSize` points square at 2x, off the main thread.
    ///
    /// An `NSImage` read from SVG keeps its vector rep and re-renders the SVG on every draw, on
    /// the main thread, for every row that shows it: the extension store lists a hundred of them.
    /// A bitmap draws for the cost of a blit. Anything already a bitmap comes back as it is.
    func rasterizedIcon(_ image: NSImage, pointSize: CGFloat) -> NSImage {
        guard image.representations.contains(where: { !($0 is NSBitmapImageRep) }) else { return image }
        let source = image.size
        guard source.width > 0, source.height > 0 else { return image }
        let scale = pointSize / max(source.width, source.height)
        let size = NSSize(width: (source.width * scale).rounded(), height: (source.height * scale).rounded())
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * 2),
            pixelsHigh: Int(size.height * 2),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return image }
        // The point size goes on the rep before a context is made from it, or the context draws
        // at 1x into the corner of the 2x bitmap.
        rep.size = size
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return image }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        let bitmap = NSImage(size: size)
        bitmap.addRepresentation(rep)
        return bitmap
    }
}
