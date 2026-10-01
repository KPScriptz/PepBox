//
//  ImageMetadataStripper.swift
//  PepBox
//
//  Removes location, camera and other metadata from images before sharing,
//  without re-encoding the pixels. Orientation is kept so photos stay upright.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageMetadataStripper {
    /// Writes a clean copy next to other temp output and returns it, or nil on failure.
    static func strip(_ url: URL, into directory: URL = FileManager.default.temporaryDirectory) -> URL? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source),
              CGImageSourceGetCount(source) > 0 else { return nil }

        let output = uniqueURL(directory.appendingPathComponent(url.lastPathComponent))
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, type, 1, nil) else { return nil }

        // Start from empty metadata, keeping only the orientation so photos stay upright.
        let metadata = CGImageMetadataCreateMutable()
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        if let orientation = properties?[kCGImagePropertyOrientation] as? NSNumber {
            CGImageMetadataSetValueMatchingImageProperty(metadata, kCGImagePropertyTIFFDictionary, kCGImagePropertyOrientation, orientation)
        }
        let options: [CFString: Any] = [
            kCGImageDestinationMetadata: metadata,
            kCGImageDestinationMergeMetadata: false,
            kCGImageMetadataShouldExcludeGPS: true,
            kCGImageMetadataShouldExcludeXMP: true
        ]

        // JPEG can drop metadata without touching the pixels. Other formats (PNG, HEIC)
        // keep some tags that way, so they're redrawn from the decoded image instead.
        let copied = UTType(type as String)?.conforms(to: .jpeg) == true
            && CGImageDestinationCopyImageSource(destination, source, options as CFDictionary, nil)
        if !copied {
            guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                try? FileManager.default.removeItem(at: output)
                return nil
            }
            var imageProperties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 1.0]
            imageProperties[kCGImagePropertyOrientation] = properties?[kCGImagePropertyOrientation]
            CGImageDestinationAddImage(destination, image, imageProperties as CFDictionary)
            guard CGImageDestinationFinalize(destination) else {
                try? FileManager.default.removeItem(at: output)
                return nil
            }
        }
        return output
    }

    private static func uniqueURL(_ url: URL) -> URL {
        var candidate = url
        var n = 2
        let base = url.deletingPathExtension().lastPathComponent, ext = url.pathExtension
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = url.deletingLastPathComponent().appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
            n += 1
        }
        return candidate
    }
}
