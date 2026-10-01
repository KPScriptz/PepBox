// Scenario: six months of shelf file actions on a temp folder: resize, rotate/flip/grayscale
// (chained on earlier outputs), metadata stripping, images → PDF, PDF merge and checksums.

import Foundation
import AppKit
import ImageIO
import PDFKit
import CryptoKit
import UniformTypeIdentifiers

private enum Kind: CaseIterable { case png, jpeg, heic, grayPNG, png16, cmykJPEG, gif, tiff }

private func makeImage(_ url: URL, width: Int, height: Int, kind: Kind, orientation: Int, seed: Int) -> Bool {
    let gray = kind == .grayPNG, cmyk = kind == .cmykJPEG, deep = kind == .png16
    let space: CGColorSpace = gray ? CGColorSpaceCreateDeviceGray() : cmyk ? CGColorSpaceCreateDeviceCMYK() : CGColorSpace(name: CGColorSpace.sRGB)!
    let info: UInt32 = gray || cmyk ? CGImageAlphaInfo.none.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
        | (deep ? CGBitmapInfo.byteOrder16Little.rawValue : 0)
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: deep ? 16 : 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: info) else { return false }
    let components = cmyk ? [0.1, 0.6, 0.2, 0.0, 1.0] : gray ? [0.4, 1.0] : [Double(seed % 7) / 7, 0.5, 1.0, 1.0]
    context.setFillColor(CGColor(colorSpace: space, components: components.map { CGFloat($0) })!)
    context.fill(CGRect(x: 0, y: 0, width: max(1, width / 3), height: height))
    guard let image = context.makeImage() else { return false }
    let type: UTType = switch kind {
    case .png, .grayPNG, .png16: .png
    case .jpeg, .cmykJPEG: .jpeg
    case .heic: .heic
    case .gif: .gif
    case .tiff: .tiff
    }
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else { return false }
    let properties: [CFString: Any] = [
        kCGImagePropertyOrientation: orientation,
        kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 32.78, kCGImagePropertyGPSLatitudeRef: "N"],
        kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFModel: "Camera \(seed)"]
    ]
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    return CGImageDestinationFinalize(destination)
}

private func pixelSize(_ url: URL) -> (w: Int, h: Int, orientation: Int)? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let p = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let w = p[kCGImagePropertyPixelWidth] as? Int, let h = p[kCGImagePropertyPixelHeight] as? Int else { return nil }
    return (w, h, (p[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1)
}

/// Size as displayed: what ImageIO draws once the file's orientation is applied.
private func uprightSize(_ url: URL) -> (w: Int, h: Int)? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                                                       kCGImageSourceCreateThumbnailWithTransform: true,
                                                                       kCGImageSourceThumbnailMaxPixelSize: 20_000] as CFDictionary) else { return nil }
    return (image.width, image.height)
}

private func decodes(_ url: URL) -> Bool {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return false }
    return CGImageSourceCreateImageAtIndex(source, 0, nil) != nil
}

func scenarioFiles(start: Int) {
    var rng = RNG(0xF11E)
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("pepbox-sim-files-\(getpid())")
    try? fm.removeItem(at: root)
    try? fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }
    func fileCount() -> Int { (try? fm.contentsOfDirectory(atPath: root.path).count) ?? -1 }

    var images: [URL] = []
    var pdfs: [URL] = []
    var ops: [String: (ok: Int, failed: Int)] = [:]
    var failuresByKind: [String: Int] = [:]
    var opIndex = 0
    var encoderRefusals = 0

    for day in 0..<182 {
        // New photos/screenshots land on the shelf most days.
        for _ in 0..<rng.range(0...3) {
            let kind = rng.pick(Kind.allCases)
            var (w, h): (Int, Int) = rng.pick([(1, 1), (8000, 1), (1, 8000), (rng.range(2...600), rng.range(2...600)),
                                               (rng.range(2...600), rng.range(2...600)), (rng.range(2...600), rng.range(2...600))])
            if rng.chance(0.05) { (w, h) = (4032, 3024) }   // a full-size phone photo now and then
            // ImageIO can't round-trip a 12 MP GIF (it writes files it can't read back); nobody shelves those.
            if kind == .gif && w * h > 4_000_000 { (w, h) = (640, 480) }
            let ext = switch kind { case .png, .grayPNG, .png16: "png"; case .jpeg, .cmykJPEG: "jpg"; case .heic: "heic"; case .gif: "gif"; case .tiff: "tiff" }
            let url = FileTools.unique(root.appendingPathComponent("IMG \(day)").appendingPathExtension(ext))
            if makeImage(url, width: w, height: h, kind: kind, orientation: rng.range(1...8), seed: day) {
                images.append(url)
                failuresByKind["\(url.lastPathComponent)"] = 0
            }
        }
        guard !images.isEmpty else { continue }

        for _ in 0..<rng.range(1...4) {
            opIndex += 1
            let before = Set((try? fm.contentsOfDirectory(atPath: root.path)) ?? [])
            let target = rng.pick(images)
            let op = rng.pick(["resize", "resize", "rotateLeft", "rotateRight", "flip", "grayscale", "strip", "pdf", "merge", "sha"])
            Crumb.set(opIndex, "files day \(day): \(op) \(target.lastPathComponent)")
            var output: URL?
            var outputs = 1
            let source = uprightSize(target)
            switch op {
            case "resize":
                let size = rng.pick([0, 1080, 2048, 3840])   // the menu: Half Size, 1080, 2048, 4K
                let longest = source.map { max($0.w, $0.h) } ?? 0
                let maxDimension = size == 0 ? longest / 2 : size
                if maxDimension < 1 { outputs = 0; break }
                output = FileTools.resizeImage(target, maxDimension: maxDimension, into: root)
                if let output, let source, let out = uprightSize(output) {
                    let expectedLongest = min(maxDimension, longest)
                    check(abs(max(out.w, out.h) - expectedLongest) <= 1, "resize \(target.lastPathComponent) \(source) to \(maxDimension): got \(out)")
                    check((out.w >= out.h) == (source.w >= source.h) || min(out.w, out.h) <= 1, "resize keeps aspect \(source) → \(out)")
                }
            case "rotateLeft", "rotateRight", "flip", "grayscale":
                let edit: FileTools.ImageEdit = ["rotateLeft": .rotateLeft, "rotateRight": .rotateRight, "flip": .flipHorizontal, "grayscale": .grayscale][op]!
                output = FileTools.editImage(target, edit, into: root)
                if let output, let source, let out = uprightSize(output) {
                    let swapped = op.hasPrefix("rotate")
                    check(out.w == (swapped ? source.h : source.w) && out.h == (swapped ? source.w : source.h),
                          "\(op) \(target.lastPathComponent) \(source) → \(out)")
                }
            case "strip":
                output = ImageMetadataStripper.strip(target, into: root)
                if let output, let source = CGImageSourceCreateWithURL(output as CFURL, nil),
                   let p = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                    check(p[kCGImagePropertyGPSDictionary] == nil, "strip left GPS in \(output.lastPathComponent)")
                    expectEq((p[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1, pixelSize(target)?.orientation ?? 1, "strip keeps orientation \(target.lastPathComponent)")
                }
            case "pdf":
                let picks = (0..<rng.range(1...5)).map { _ in rng.pick(images) }
                output = FileTools.imagesToPDF(picks, into: root)
                if let output { expectEq(PDFDocument(url: output)?.pageCount, picks.filter { NSImage(contentsOf: $0) != nil }.count, "images → PDF page count") }
                if let output { pdfs.append(output) }
            case "merge":
                guard pdfs.count >= 1 else { outputs = 0; break }
                let picks = (0..<rng.range(2...3)).map { _ in rng.pick(pdfs) }
                output = FileTools.mergePDFs(picks, into: root)
                let expected = picks.compactMap { PDFDocument(url: $0)?.pageCount }.reduce(0, +)
                if let output { expectEq(PDFDocument(url: output)?.pageCount, expected, "merged page count") }
                if let output { pdfs.append(output) }
            default:
                outputs = 0
                let data = (try? Data(contentsOf: target)) ?? Data()
                expectEq(FileTools.sha256(target), SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), "sha256 \(target.lastPathComponent)")
            }
            ops[op, default: (0, 0)].ok += output != nil || outputs == 0 ? 1 : 0
            if output == nil && outputs == 1, target.pathExtension == "heic", let s = pixelSize(target), min(s.w, s.h) <= 1 {
                // The HEIC encoder refuses 1-pixel-wide images; nil is the right answer there.
                encoderRefusals += 1
            } else if output == nil && outputs == 1 {
                ops[op, default: (0, 0)].failed += 1
                let kind = target.pathExtension + (pixelSize(target).map { " \($0.w)x\($0.h) o\($0.orientation)" } ?? "")
                check(false, "\(op) returned nil for a valid image: \(target.lastPathComponent) (\(kind), \(colorModel(target)))")
            }
            let after = Set((try? fm.contentsOfDirectory(atPath: root.path)) ?? [])
            if let output {
                check(!before.contains(output.lastPathComponent), "\(op) overwrote an existing file: \(output.lastPathComponent)")
                check(decodes(output) || output.pathExtension == "pdf", "\(op) wrote an unreadable file \(output.lastPathComponent)")
                if op != "pdf" && op != "merge" { images.append(output) }
            }
            let strays = after.subtracting(before).filter { output?.lastPathComponent != $0 }
            check(strays.isEmpty, "\(op) on \(target.lastPathComponent) left stray files: \(strays.sorted())")
        }
    }
    if encoderRefusals > 0 { note("\(encoderRefusals) actions on 1-pixel-wide HEIC images returned nil (HEIC encoder limit; ImageIO leaves a hidden .name-XXXX temp file behind each time)") }
    note("\(opIndex) shelf actions on \(fileCount()) files; per action ok/failed: " +
         ops.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value.ok)/\($0.value.failed)" }.joined(separator: ", "))
}

private func colorModel(_ url: URL) -> String {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let p = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return "?" }
    return "\(p[kCGImagePropertyColorModel] ?? "?") \(p[kCGImagePropertyDepth] ?? "?")-bit"
}
