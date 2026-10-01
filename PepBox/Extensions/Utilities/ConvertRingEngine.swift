//
//  ConvertRingEngine.swift
//  PepBox
//
//  Does what a Convert Ring segment says: each conversion is written to a temp
//  folder first, then moved next to its original under a name that's free, so
//  a failed or half-written file never lands beside the user's files.
//

import AppKit
import AVFoundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import Vision

enum ConvertRingEngine {
    struct Result {
        var outputs: [URL] = []
        var failures = 0
        var message: String?   // e.g. a decoded QR code
    }

    static var ffmpegPath: String? { FFmpegInstallManager.shared.findFFmpegPath() }

    static func run(_ target: RingTarget, on urls: [URL]) async -> Result {
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("PepBox-Convert-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        var result = Result()
        switch target.action {
        // Many files in, one file out.
        case .mergePDFs:
            record(FileTools.mergePDFs(urls, into: work), placedBeside: urls[0], named: "Merged", in: &result)
        case .imagesToPDF:
            record(FileTools.imagesToPDF(urls, into: work), placedBeside: urls[0], named: urls.count == 1 ? nil : "Images", in: &result)
        case .zip:
            record(zip(urls, into: work), placedBeside: urls[0], named: urls.count == 1 ? nil : "Archive", in: &result)
        case .readQR:
            let codes = urls.flatMap(readQR)
            if codes.isEmpty {
                result.failures = urls.count
            } else {
                let text = codes.joined(separator: "\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                result.message = text
            }
        // One file in, one (or a folder) out, per file.
        default:
            for url in urls {
                let output = await convert(url, target.action, into: work)
                // Same-format tools say what they did, so the copy isn't just "Photo 2.jpg".
                let base = url.deletingPathExtension().lastPathComponent
                let named: String? = switch target.action {
                case .compress: base + " compressed"
                case .stripMetadata: base + " clean"
                default: nil
                }
                record(output, placedBeside: url, named: named, in: &result)
            }
        }
        return result
    }

    /// Moves a finished temp file next to `source`. `named` replaces the base name (for merged outputs).
    private static func record(_ temp: URL?, placedBeside source: URL, named: String?, in result: inout Result) {
        guard let temp, FileManager.default.fileExists(atPath: temp.path) else { result.failures += 1; return }
        let folder = source.deletingLastPathComponent()
        let taken = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
        var isFolder: ObjCBool = false
        FileManager.default.fileExists(atPath: temp.path, isDirectory: &isFolder)
        // ".src" stands in for an extension so outputName swaps it, keeping dots in the name.
        let sourceName = named.map { $0 + ".src" } ?? (isFolder.boolValue ? temp.lastPathComponent + ".src" : source.lastPathComponent)
        let ext = temp.pathExtension
        let destination = folder.appendingPathComponent(ConvertRing.outputName(for: sourceName, ext: ext, taken: taken))
        do {
            try FileManager.default.moveItem(at: temp, to: destination)
            result.outputs.append(destination)
        } catch {
            result.failures += 1
        }
    }

    private static func convert(_ url: URL, _ action: RingTarget.Action, into work: URL) async -> URL? {
        let base = url.deletingPathExtension().lastPathComponent
        func out(_ ext: String) -> URL { work.appendingPathComponent(base).appendingPathExtension(ext) }

        switch action {
        case .image(let ext):
            if ConvertRing.ffmpegImageWrites.contains(ext) { return await ffmpeg(url, out(ext)) }
            return writeImage(url, to: out(ext), ext: ext)
        case .audio(let ext):
            if ConvertRing.ffmpegAudioWrites.contains(ext) { return await ffmpeg(url, out(ext)) }
            return await writeAudio(url, to: out(ext), ext: ext)
        case .video(let ext):
            if ConvertRing.ffmpegVideoWrites.contains(ext) { return await ffmpeg(url, out(ext)) }
            if let exported = await exportVideo(url, to: out(ext), ext: ext) { return exported }
            return await ffmpeg(url, out(ext))  // nil when FFmpeg isn't installed
        case .videoToAudio(let ext):
            if ext == "mp3" { return await ffmpeg(url, out(ext)) }
            return await MediaConverter.exportAudio(from: url, to: out(ext), format: ext == "wav" ? .wav : .m4a)
        case .videoToGIF:
            return await FileTools.videoToGIF(url, into: work)
        case .pdfToPNG:
            let folder = work.appendingPathComponent(base + " Pages")
            if let document = PDFDocument(url: url), document.pageCount == 1 {
                // One page: a single image instead of a folder.
                guard let folderURL = MediaConverter.renderPDFPages(from: url, into: folder),
                      let page = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil).first else { return nil }
                let single = out("png")
                try? FileManager.default.moveItem(at: page, to: single)
                return single
            }
            return MediaConverter.renderPDFPages(from: url, into: folder)
        case .pdfToText:
            guard let text = PDFDocument(url: url)?.string, !text.isEmpty else { return nil }
            return write(text, to: out("txt"))
        case .subtitle(let ext):
            guard let text = FileTools.textContents(url) else { return nil }
            return write(ext == "vtt" ? ConvertRing.srtToVTT(text) : ConvertRing.vttToSRT(text), to: out(ext))
        case .documentToText:
            guard let attributed = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) else { return nil }
            return write(attributed.string, to: out("txt"))
        case .compress:
            guard let compressed = await FileCompressor.shared.compress(url: url, mode: .preset(.medium)) else { return nil }
            // Keep the original's extension; the compressor may have written elsewhere.
            let destination = out(compressed.pathExtension.isEmpty ? url.pathExtension : compressed.pathExtension)
            try? FileManager.default.moveItem(at: compressed, to: destination)
            return destination
        case .stripMetadata:
            return ImageMetadataStripper.strip(url, into: work)
        case .splitPDF:
            guard let document = PDFDocument(url: url), document.pageCount > 0 else { return nil }
            let folder = work.appendingPathComponent(base + " Pages")
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let names = FileTools.sequentialNames(base: base, count: document.pageCount)
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let single = PDFDocument()
                single.insert(page, at: 0)
                single.write(to: folder.appendingPathComponent(names[index]).appendingPathExtension("pdf"))
            }
            return folder
        case .videoFrame:
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            guard let image = try? await generator.image(at: .zero).image else { return nil }
            return writeCGImage(image, to: out("png"), type: .png)
        case .mergePDFs, .imagesToPDF, .zip, .readQR:
            return nil  // handled for the whole group in run(_:on:)
        }
    }

    // MARK: Images

    private static func utType(forImage ext: String) -> UTType? {
        switch ext {
        case "jpg": return .jpeg
        case "png": return .png
        case "heic": return .heic
        case "avif": return UTType("public.avif")
        case "tiff": return .tiff
        case "gif": return .gif
        case "bmp": return .bmp
        case "pdf": return .pdf
        default: return nil
        }
    }

    private static func writeImage(_ url: URL, to destination: URL, ext: String) -> URL? {
        guard let type = utType(forImage: ext),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        if type == .pdf {
            guard let image = NSImage(contentsOf: url), let page = PDFPage(image: image) else { return nil }
            let document = PDFDocument()
            document.insert(page, at: 0)
            return document.write(to: destination) ? destination : nil
        }
        // Animated GIF → GIF keeps every frame; everything else takes the first frame.
        let count = type == .gif ? CGImageSourceGetCount(source) : 1
        guard count > 0, let target = CGImageDestinationCreateWithURL(destination as CFURL, type.identifier as CFString, count, nil) else { return nil }
        let lossy: Set<UTType> = [.jpeg, .heic]
        let options: [CFString: Any] = lossy.contains(type) || ext == "avif"
            ? [kCGImageDestinationLossyCompressionQuality: 0.88] : [:]
        for index in 0..<count {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { continue }
            // JPEG and BMP have no alpha: flatten onto white so transparent areas don't turn black.
            let frame = (type == .jpeg || type == .bmp) ? flattened(image) ?? image : image
            CGImageDestinationAddImage(target, frame, options as CFDictionary)
        }
        guard CGImageDestinationFinalize(target) else { return nil }
        return destination
    }

    private static func flattened(_ image: CGImage) -> CGImage? {
        guard image.alphaInfo != .none, image.alphaInfo != .noneSkipLast, image.alphaInfo != .noneSkipFirst,
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(.white)
        context.fill(rect)
        context.draw(image, in: rect)
        return context.makeImage()
    }

    private static func writeCGImage(_ image: CGImage, to destination: URL, type: UTType) -> URL? {
        guard let target = CGImageDestinationCreateWithURL(destination as CFURL, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(target, image, nil)
        return CGImageDestinationFinalize(target) ? destination : nil
    }

    // MARK: Audio and video

    private static func writeAudio(_ url: URL, to destination: URL, ext: String) async -> URL? {
        switch ext {
        case "m4a": return await MediaConverter.exportAudio(from: url, to: destination, format: .m4a)
        case "wav": return await MediaConverter.exportAudio(from: url, to: destination, format: .wav)
        case "aiff": return await MediaConverter.exportAudio(from: url, to: destination, format: .aiff)
        case "flac":
            return transcodePCM(url, to: destination, settings: [
                AVFormatIDKey: kAudioFormatFLAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 2
            ])
        default:
            return ffmpegPath != nil ? await ffmpeg(url, destination) : nil
        }
    }

    /// Decodes with AVAudioFile and re-encodes (FLAC). Reads files AVAudioFile can open (not video).
    private static func transcodePCM(_ url: URL, to destination: URL, settings: [String: Any]) -> URL? {
        guard let input = try? AVAudioFile(forReading: url) else { return nil }
        var settings = settings
        settings[AVSampleRateKey] = input.processingFormat.sampleRate
        settings[AVNumberOfChannelsKey] = min(2, input.processingFormat.channelCount)
        guard input.processingFormat.channelCount <= 2,
              let output = try? AVAudioFile(forWriting: destination, settings: settings,
                                            commonFormat: .pcmFormatFloat32, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: 65_536) else { return nil }
        do {
            while input.framePosition < input.length {
                try input.read(into: buffer)
                if buffer.frameLength == 0 { break }
                try output.write(from: buffer)
            }
        } catch {
            try? FileManager.default.removeItem(at: destination)
            return nil
        }
        return destination
    }

    private static func exportVideo(_ url: URL, to destination: URL, ext: String) async -> URL? {
        let asset = AVURLAsset(url: url)
        guard (try? await asset.load(.isExportable)) == true,
              let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        do {
            try await session.export(to: destination, as: ext == "mov" ? .mov : .mp4)
            return destination
        } catch {
            return nil
        }
    }

    private static func ffmpeg(_ input: URL, _ output: URL) async -> URL? {
        guard let path = ffmpegPath else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ConvertRing.ffmpegArguments(input: input.path, output: output.path)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let status: Int32 = await withCheckedContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do { try process.run() } catch { process.terminationHandler = nil; continuation.resume(returning: -1) }
        }
        guard status == 0, FileManager.default.fileExists(atPath: output.path) else {
            try? FileManager.default.removeItem(at: output)
            return nil
        }
        return output
    }

    // MARK: Other

    private static func write(_ text: String, to destination: URL) -> URL? {
        (try? text.write(to: destination, atomically: true, encoding: .utf8)) == nil ? nil : destination
    }

    /// Zips with ditto, leaving out resource forks and extended attributes (no __MACOSX folder).
    private static func zip(_ urls: [URL], into work: URL) -> URL? {
        let name = urls.count == 1 ? urls[0].lastPathComponent : "Archive"
        let output = work.appendingPathComponent(name).appendingPathExtension("zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        if urls.count == 1 {
            process.arguments = ["-c", "-k", "--norsrc", "--noextattr", "--noqtn", "--keepParent", urls[0].path, output.path]
        } else {
            // ditto zips one item, so copy the files into one folder first.
            let staging = work.appendingPathComponent("Archive")
            try? FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            for url in urls {
                try? FileManager.default.copyItem(at: url, to: FileTools.unique(staging.appendingPathComponent(url.lastPathComponent)))
            }
            process.arguments = ["-c", "-k", "--norsrc", "--noextattr", "--noqtn", staging.path, output.path]
        }
        do { try process.run() } catch { return nil }
        process.waitUntilExit()
        return process.terminationStatus == 0 ? output : nil
    }

    private static func readQR(_ url: URL) -> [String] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return [] }
        let request = VNDetectBarcodesRequest()
        try? VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap(\.payloadStringValue)
    }
}
