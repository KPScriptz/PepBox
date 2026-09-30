//
//  FileTools.swift
//  PepBox
//
//  Shelf file actions and clipboard text transforms: resize images, merge
//  PDFs, turn images into a PDF, SHA-256 checksums, and text clean-ups.
//  Outputs go to the temporary folder and are put on the shelf by the caller.
//

import AppKit
import AVFoundation
import CryptoKit
import ImageIO
import PDFKit
import UniformTypeIdentifiers

enum FileTools {
    // MARK: Resize image

    /// Scales an image so its longest side is `maxDimension` pixels (never enlarges). Keeps the format.
    static func resizeImage(_ url: URL, maxDimension: Int, into directory: URL = FileManager.default.temporaryDirectory) -> URL? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,  // bakes in orientation
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let base = url.deletingPathExtension().lastPathComponent
        let output = unique(directory.appendingPathComponent("\(base) \(max(image.width, image.height))px").appendingPathExtension(url.pathExtension))
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, type, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output : nil
    }

    // MARK: PDFs

    /// Appends the pages of several PDFs, in order, into one document.
    static func mergePDFs(_ urls: [URL], into directory: URL = FileManager.default.temporaryDirectory) -> URL? {
        let merged = PDFDocument()
        for url in urls {
            guard let document = PDFDocument(url: url) else { return nil }
            for index in 0..<document.pageCount {
                if let page = document.page(at: index) { merged.insert(page, at: merged.pageCount) }
            }
        }
        guard merged.pageCount > 0 else { return nil }
        let output = unique(directory.appendingPathComponent("Merged.pdf"))
        return merged.write(to: output) ? output : nil
    }

    /// One page per image, each page the size of its image.
    static func imagesToPDF(_ urls: [URL], into directory: URL = FileManager.default.temporaryDirectory) -> URL? {
        let document = PDFDocument()
        for url in urls {
            guard let image = NSImage(contentsOf: url), let page = PDFPage(image: image) else { continue }
            document.insert(page, at: document.pageCount)
        }
        guard document.pageCount > 0 else { return nil }
        let name = urls.count == 1 ? urls[0].deletingPathExtension().lastPathComponent : "Images"
        let output = unique(directory.appendingPathComponent(name).appendingPathExtension("pdf"))
        return document.write(to: output) ? output : nil
    }

    // MARK: Checksum

    /// SHA-256 of a file, read in 1 MB pieces so large files don't load into memory.
    static func sha256(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try? handle.read(upToCount: 1 << 20), !data.isEmpty {
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Video → GIF

    /// Makes a looping GIF from the start of a video: up to `maxSeconds`, `fps` frames a second, `maxWidth` wide.
    static func videoToGIF(_ url: URL, maxWidth: CGFloat = 480, fps: Double = 12, maxSeconds: Double = 15,
                           into directory: URL = FileManager.default.temporaryDirectory) async -> URL? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration).seconds, duration > 0 else { return nil }
        let length = min(duration, maxSeconds)
        let frameCount = max(1, Int(length * fps))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxWidth, height: maxWidth * 4)
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 60)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 60)

        let output = unique(directory.appendingPathComponent(url.deletingPathExtension().lastPathComponent).appendingPathExtension("gif"))
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, frameCount, nil) else { return nil }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]] as CFDictionary

        let times = (0..<frameCount).map { CMTime(seconds: Double($0) / fps, preferredTimescale: 600) }
        var added = 0
        for await result in generator.images(for: times) {
            if let image = try? result.image {
                CGImageDestinationAddImage(destination, image, frameProperties)
                added += 1
            }
        }
        guard added > 0, CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: output)
            return nil
        }
        return output
    }

    // MARK: Copy helpers

    /// "data:image/png;base64,…" for pasting an image into HTML/CSS. Nil above 5 MB.
    static func dataURI(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url), data.count <= 5_000_000 else { return nil }
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        return "data:\(mime);base64,\(data.base64EncodedString())"
    }

    /// Text of a plain-text file (code, Markdown, CSV…) up to 2 MB.
    static func textContents(_ url: URL) -> String? {
        guard (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map({ $0 <= 2_000_000 }) == true,
              let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// "Photo" × 12 → "Photo 01" … "Photo 12" (zero-padded to the widest number).
    static func sequentialNames(base: String, count: Int) -> [String] {
        let width = String(count).count
        return (1...max(count, 1)).map { base + " " + String(format: "%0\(width)d", $0) }
    }

    static func unique(_ url: URL) -> URL {
        var candidate = url
        var n = 2
        let base = url.deletingPathExtension().lastPathComponent, ext = url.pathExtension
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = url.deletingLastPathComponent().appendingPathComponent("\(base) \(n)")
            if !ext.isEmpty { candidate = candidate.appendingPathExtension(ext) }
            n += 1
        }
        return candidate
    }
}

// MARK: - Text transforms (clipboard)

enum TextTransform: String, CaseIterable, Identifiable {
    case uppercase = "UPPERCASE"
    case lowercase = "lowercase"
    case titleCase = "Title Case"
    case sentenceCase = "Sentence case"
    case trim = "Trim Whitespace"
    case singleLine = "Join Into One Line"
    case sortLines = "Sort Lines"
    case uniqueLines = "Remove Duplicate Lines"
    case prettyJSON = "Pretty-Print JSON"
    case slug = "slug-case"

    var id: String { rawValue }

    /// The transformed text, or nil when it doesn't apply (e.g. JSON that doesn't parse).
    func apply(_ text: String) -> String? {
        switch self {
        case .uppercase: return text.uppercased()
        case .lowercase: return text.lowercased()
        case .titleCase: return text.capitalized
        case .sentenceCase:
            var result = ""
            var capitalizeNext = true
            for character in text.lowercased() {
                if capitalizeNext && character.isLetter {
                    result += character.uppercased()
                    capitalizeNext = false
                } else {
                    result.append(character)
                }
                if ".!?".contains(character) { capitalizeNext = true }
            }
            return result
        case .trim:
            return text.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .singleLine:
            return text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }.joined(separator: " ")
        case .sortLines:
            return text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }.joined(separator: "\n")
        case .uniqueLines:
            var seen = Set<String>()
            return text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                .filter { seen.insert($0).inserted }.joined(separator: "\n")
        case .prettyJSON:
            guard let data = text.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
                  let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            else { return nil }
            return String(decoding: pretty, as: UTF8.self)
        case .slug:
            let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
            let parts = folded.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: "-")
        }
    }
}
