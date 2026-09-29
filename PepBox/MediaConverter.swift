//
//  MediaConverter.swift
//  PepBox
//
//  On-device conversions for the Convert menu: audio out of videos, audio to
//  other audio formats, and PDF pages to PNG images. Built on AVFoundation and
//  PDFKit, so nothing is uploaded and no extra tools are needed.
//

import AVFoundation
import AppKit
import PDFKit

enum MediaConverter {
    /// Writes the audio track of an audio or video file as M4A, WAV or AIFF.
    static func exportAudio(from source: URL, to destination: URL, format: ConversionFormat) async -> URL? {
        let asset = AVURLAsset(url: source)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else { return nil }
        try? FileManager.default.removeItem(at: destination)

        if format == .m4a {
            guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else { return nil }
            do {
                try await session.export(to: destination, as: .m4a)
                return destination
            } catch {
                return nil
            }
        }

        // WAV / AIFF: decode to 16-bit PCM with a reader and write it out.
        let fileType: AVFileType = format == .wav ? .wav : .aiff
        guard let reader = try? AVAssetReader(asset: asset),
              let writer = try? AVAssetWriter(outputURL: destination, fileType: fileType) else { return nil }

        let descriptions = (try? await track.load(.formatDescriptions)) ?? []
        let basic = descriptions.first.flatMap { CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee }
        let sampleRate = basic?.mSampleRate ?? 44_100
        let channels = max(1, min(Int(basic?.mChannelsPerFrame ?? 2), 2))
        let pcm: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: format == .aiff,
            AVLinearPCMIsNonInterleaved: false
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: pcm)
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: pcm)
        input.expectsMediaDataInRealTime = false
        guard reader.canAdd(output), writer.canAdd(input) else { return nil }
        reader.add(output)
        writer.add(input)
        guard reader.startReading(), writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)

        let queue = DispatchQueue(label: "PepBox.MediaConverter.pcm")
        let finished: Bool = await withCheckedContinuation { continuation in
            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData {
                    if let buffer = output.copyNextSampleBuffer() {
                        if !input.append(buffer) {
                            reader.cancelReading()
                            input.markAsFinished()
                            continuation.resume(returning: false)
                            return
                        }
                    } else {
                        input.markAsFinished()
                        continuation.resume(returning: reader.status == .completed)
                        return
                    }
                }
            }
        }
        await writer.finishWriting()
        guard finished, writer.status == .completed else {
            try? FileManager.default.removeItem(at: destination)
            return nil
        }
        return destination
    }

    /// Renders every page of a PDF as a PNG (2× scale) into a new folder and returns the folder.
    static func renderPDFPages(from source: URL, into folder: URL, scale: CGFloat = 2) -> URL? {
        guard let document = PDFDocument(url: source), document.pageCount > 0 else { return nil }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        let base = source.deletingPathExtension().lastPathComponent
        let digits = String(document.pageCount).count
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let width = Int(bounds.width * scale), height = Int(bounds.height * scale)
            guard width > 0, height > 0,
                  let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -bounds.minX, y: -bounds.minY)
            page.draw(with: .mediaBox, to: context)
            guard let image = context.makeImage() else { continue }
            let number = String(format: "%0\(digits)d", index + 1)
            let url = folder.appendingPathComponent("\(base) \(number).png")
            let rep = NSBitmapImageRep(cgImage: image)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
        return folder
    }
}
