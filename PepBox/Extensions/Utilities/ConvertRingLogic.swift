//
//  ConvertRingLogic.swift
//  PepBox
//
//  The decisions behind the Convert Ring: which formats and tools to offer for
//  the files being dragged, which ring segment the pointer is over, what the
//  converted files are called, and the FFmpeg arguments for formats macOS
//  can't write itself. No UI or file access, so it can be tested.
//

import Foundation

enum ConvertKind: String, Equatable {
    case image, audio, video, pdf, subtitle, document, other

    private static let table: [String: ConvertKind] = {
        var map: [String: ConvertKind] = [:]
        for ext in ["jpg", "jpeg", "png", "heic", "heif", "avif", "tif", "tiff", "gif", "bmp", "webp", "jp2", "ico", "icns", "dng", "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2", "psd", "tga", "exr"] { map[ext] = .image }
        for ext in ["mp3", "m4a", "aac", "wav", "aif", "aiff", "flac", "caf", "opus", "ogg", "oga", "wma", "alac", "m4b"] { map[ext] = .audio }
        for ext in ["mp4", "mov", "m4v", "mkv", "webm", "avi", "wmv", "flv", "mpg", "mpeg", "3gp", "ts", "mts", "m2ts"] { map[ext] = .video }
        map["pdf"] = .pdf
        for ext in ["srt", "vtt"] { map[ext] = .subtitle }
        for ext in ["docx", "doc", "rtf", "rtfd", "odt", "html", "htm", "txt", "md", "webarchive"] { map[ext] = .document }
        return map
    }()

    init(extension ext: String) {
        self = Self.table[ext.lowercased()] ?? .other
    }

    /// The kind every file shares, or nil for a mix (a mix only gets the tools that work on anything).
    static func common(_ extensions: [String]) -> ConvertKind? {
        let kinds = Set(extensions.map(ConvertKind.init(extension:)))
        return kinds.count == 1 ? kinds.first : nil
    }
}

/// One choice in the ring.
struct RingTarget: Equatable, Identifiable {
    enum Action: Equatable {
        case image(ext: String)        // ImageIO, or FFmpeg for webp
        case audio(ext: String)        // AVFoundation, or FFmpeg
        case video(ext: String)        // AVFoundation for mp4/mov, FFmpeg otherwise
        case videoToAudio(ext: String)
        case videoToGIF
        case pdfToPNG
        case pdfToText
        case subtitle(ext: String)
        case documentToText
        case zip
        case compress
        case stripMetadata
        case mergePDFs
        case splitPDF
        case imagesToPDF
        case readQR
        case videoFrame
    }

    let id: String
    let title: String
    let symbol: String
    let action: Action
    var needsFFmpeg = false
}

enum ConvertRing {
    /// Formats ImageIO can write on this Mac (checked at runtime; webp is read-only).
    static let nativeImageWrites: Set<String> = ["jpg", "png", "heic", "avif", "tiff", "gif", "bmp", "pdf"]
    static let ffmpegImageWrites: Set<String> = ["webp"]
    static let nativeAudioWrites: Set<String> = ["m4a", "wav", "aiff", "flac", "caf"]
    static let ffmpegAudioWrites: Set<String> = ["mp3", "ogg", "opus"]
    static let nativeVideoWrites: Set<String> = ["mp4", "mov"]
    static let ffmpegVideoWrites: Set<String> = ["mkv", "webm", "avi"]

    /// The most a ring shows at once; more would make the segments too thin to hit.
    static let maxSegments = 10

    /// "jpeg" → "jpg", "tif" → "tiff": so a JPEG isn't offered "JPG".
    static func canonical(_ ext: String) -> String {
        switch ext.lowercased() {
        case "jpeg", "jpe": return "jpg"
        case "tif": return "tiff"
        case "aif", "aifc": return "aiff"
        case "heif": return "heic"
        case "htm": return "html"
        case "oga": return "ogg"
        default: return ext.lowercased()
        }
    }

    /// Conversions for the files being dragged (Shift-drag).
    static func formatTargets(for extensions: [String], ffmpeg: Bool) -> [RingTarget] {
        guard !extensions.isEmpty, let kind = ConvertKind.common(extensions) else { return [] }
        let sources = Set(extensions.map(canonical))
        // Hide the format the files are already in; when every file is the same format.
        func keep(_ ext: String) -> Bool { !(sources.count == 1 && sources.contains(ext)) }

        var targets: [RingTarget] = []
        func add(_ ext: String, _ symbol: String, _ action: RingTarget.Action, ffmpegOnly: Bool = false) {
            guard keep(ext), !ffmpegOnly || ffmpeg else { return }
            targets.append(RingTarget(id: "\(kind.rawValue).\(ext)", title: ext.uppercased(), symbol: symbol, action: action, needsFFmpeg: ffmpegOnly))
        }

        switch kind {
        case .image:
            for ext in ["jpg", "png", "heic", "webp", "avif", "tiff", "gif", "pdf", "bmp"] {
                add(ext, ext == "pdf" ? "doc.richtext" : "photo", .image(ext: ext), ffmpegOnly: ffmpegImageWrites.contains(ext))
            }
        case .audio:
            for ext in ["mp3", "m4a", "wav", "flac", "aiff", "opus", "ogg"] {
                add(ext, "waveform", .audio(ext: ext), ffmpegOnly: ffmpegAudioWrites.contains(ext))
            }
        case .video:
            for ext in ["mp4", "mov", "mkv", "webm"] {
                add(ext, "film", .video(ext: ext), ffmpegOnly: ffmpegVideoWrites.contains(ext))
            }
            targets.append(RingTarget(id: "video.gif", title: "GIF", symbol: "photo.stack", action: .videoToGIF))
            targets.append(RingTarget(id: "video.m4a", title: "M4A", symbol: "waveform", action: .videoToAudio(ext: "m4a")))
            if ffmpeg {
                targets.append(RingTarget(id: "video.mp3", title: "MP3", symbol: "waveform", action: .videoToAudio(ext: "mp3"), needsFFmpeg: true))
            }
            targets.append(RingTarget(id: "video.wav", title: "WAV", symbol: "waveform", action: .videoToAudio(ext: "wav")))
        case .pdf:
            targets.append(RingTarget(id: "pdf.png", title: "PNG", symbol: "photo.stack", action: .pdfToPNG))
            targets.append(RingTarget(id: "pdf.txt", title: "TXT", symbol: "doc.plaintext", action: .pdfToText))
        case .subtitle:
            add("srt", "captions.bubble", .subtitle(ext: "srt"))
            add("vtt", "captions.bubble", .subtitle(ext: "vtt"))
        case .document:
            add("txt", "doc.plaintext", .documentToText)
        case .other:
            break
        }
        return Array(targets.prefix(maxSegments))
    }

    /// Tools for the files being dragged (Option-Shift-drag).
    static func toolTargets(for extensions: [String]) -> [RingTarget] {
        guard !extensions.isEmpty else { return [] }
        let kind = ConvertKind.common(extensions)
        let many = extensions.count > 1
        var targets: [RingTarget] = []
        func add(_ id: String, _ title: String, _ symbol: String, _ action: RingTarget.Action) {
            targets.append(RingTarget(id: "tool.\(id)", title: title, symbol: symbol, action: action))
        }
        if [.image, .video, .pdf].contains(kind) { add("compress", "Compress", "arrow.down.right.and.arrow.up.left", .compress) }
        if kind == .image {
            add("strip", "No Metadata", "eye.slash", .stripMetadata)
            add("imagesToPDF", "To One PDF", "doc.on.doc", .imagesToPDF)
            add("qr", "Read QR", "qrcode.viewfinder", .readQR)
        }
        if kind == .pdf {
            if many { add("merge", "Merge", "doc.on.doc", .mergePDFs) }
            add("split", "Split Pages", "square.split.2x1", .splitPDF)
        }
        if kind == .video { add("frame", "First Frame", "photo", .videoFrame) }
        add("zip", "Zip", "doc.zipper", .zip)
        return Array(targets.prefix(maxSegments))
    }

    // MARK: Geometry

    /// The segment under a point given relative to the ring's center (y up), or nil
    /// in the hole (cancel) or outside the ring. Segment 0 starts at 12 o'clock and
    /// they go clockwise.
    static func segment(at point: CGPoint, count: Int, innerRadius: CGFloat, outerRadius: CGFloat) -> Int? {
        guard count > 0 else { return nil }
        let distance = hypot(point.x, point.y)
        guard distance >= innerRadius, distance <= outerRadius else { return nil }
        // Clockwise angle from 12 o'clock, 0..<2π.
        var angle = atan2(point.x, point.y)
        if angle < 0 { angle += 2 * .pi }
        let width = 2 * .pi / CGFloat(count)
        // Segments are centered on their angle, so shift by half a segment.
        let shifted = (angle + width / 2).truncatingRemainder(dividingBy: 2 * .pi)
        return min(count - 1, Int(shifted / width))
    }

    /// Center angle of a segment, clockwise from 12 o'clock, in radians.
    static func centerAngle(of index: Int, count: Int) -> CGFloat {
        2 * .pi / CGFloat(max(count, 1)) * CGFloat(index)
    }

    // MARK: Naming

    /// "Photo.HEIC" + "jpg" → "Photo.jpg", or "Photo 2.jpg" when taken. `taken` holds names
    /// already in the folder (compared case-insensitively, like APFS).
    static func outputName(for source: String, ext: String, taken: Set<String>) -> String {
        let base = (source as NSString).deletingPathExtension
        let lower = Set(taken.map { $0.lowercased() })
        let suffix = ext.isEmpty ? "" : "." + ext
        var name = base + suffix
        var n = 2
        // Never overwrite the source itself, even if it has the same extension.
        while lower.contains(name.lowercased()) || name.lowercased() == source.lowercased() {
            name = "\(base) \(n)\(suffix)"
            n += 1
        }
        return name
    }

    // MARK: Subtitles

    /// SubRip → WebVTT: header, "," → "." in timestamps, cue numbers dropped.
    static func srtToVTT(_ srt: String) -> String {
        let text = srt.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\u{FEFF}", with: "")
        var out = ["WEBVTT", ""]
        for block in text.components(separatedBy: "\n\n") {
            var lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            while lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeFirst() }
            guard !lines.isEmpty else { continue }
            if !lines[0].contains("-->"), lines.count > 1, lines[1].contains("-->") { lines.removeFirst() }
            guard lines.first?.contains("-->") == true else { continue }
            lines[0] = lines[0].replacingOccurrences(of: ",", with: ".")
            out.append(contentsOf: lines)
            out.append("")
        }
        return out.joined(separator: "\n")
    }

    /// WebVTT → SubRip: numbered cues, "." → "," in timestamps, hours added, cue settings and notes dropped.
    static func vttToSRT(_ vtt: String) -> String {
        let text = vtt.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\u{FEFF}", with: "")
        var out: [String] = []
        var number = 0
        for block in text.components(separatedBy: "\n\n") {
            var lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            while lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeFirst() }
            guard let timing = lines.firstIndex(where: { $0.contains("-->") }) else { continue }  // header, NOTE, STYLE
            let parts = lines[timing].components(separatedBy: "-->")
            guard parts.count == 2 else { continue }
            let start = srtTime(parts[0]), end = srtTime(parts[1].split(separator: " ", omittingEmptySubsequences: true).first.map(String.init) ?? "")
            guard let start, let end else { continue }
            number += 1
            out.append(String(number))
            out.append("\(start) --> \(end)")
            out.append(contentsOf: lines[(timing + 1)...].filter { !$0.isEmpty })
            out.append("")
        }
        return out.joined(separator: "\n")
    }

    /// "01:02.500" or "1:01:02.5" → "00:01:02,500".
    private static func srtTime(_ raw: String) -> String? {
        let parts = raw.trimmingCharacters(in: .whitespaces).split(separator: ":").map(String.init)
        guard (2...3).contains(parts.count) else { return nil }
        let secParts = parts.last!.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard let h = parts.count == 3 ? Int(parts[0]) : 0,
              let m = Int(parts[parts.count - 2]),
              let s = Int(secParts[0]) else { return nil }
        let fraction = secParts.count > 1 ? secParts[1] : "0"
        guard let ms = Int((fraction + "000").prefix(3)) else { return nil }
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, ms)
    }

    // MARK: FFmpeg

    /// Arguments for converting `input` to `output` (format taken from the output's extension).
    static func ffmpegArguments(input: String, output: String) -> [String] {
        let ext = (output as NSString).pathExtension.lowercased()
        var args = ["-hide_banner", "-loglevel", "error", "-nostdin", "-y", "-i", input]
        switch ext {
        case "webp": args += ["-quality", "85"]
        case "mp3": args += ["-vn", "-codec:a", "libmp3lame", "-q:a", "2"]
        case "ogg": args += ["-vn", "-codec:a", "libvorbis", "-q:a", "5"]
        case "opus": args += ["-vn", "-codec:a", "libopus", "-b:a", "128k"]
        case "webm": args += ["-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-c:a", "libopus"]
        case "mkv": args += ["-c", "copy"]
        case "avi": args += ["-c:v", "mpeg4", "-q:v", "4", "-c:a", "libmp3lame"]
        default: break
        }
        return args + [output]
    }
}
