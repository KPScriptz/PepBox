//
//  FileTools.swift
//  PepBox
//
//  Shelf file actions and clipboard text transforms: resize images, merge
//  PDFs, turn images into a PDF, SHA-256 checksums, and text clean-ups.
//  Outputs go to the temporary folder and are put on the shelf by the caller.
//

import AppKit
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
