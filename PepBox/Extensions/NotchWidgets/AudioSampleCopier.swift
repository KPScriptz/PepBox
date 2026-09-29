//
//  AudioSampleCopier.swift
//  PepBox
//
//  App Volume's real-time sample copy. No app dependencies, so
//  scripts/logic-tests can check channel mapping, gain and clipping.
//

import CoreAudio

enum AudioSampleCopier {
    /// Copies Float32 samples from the tap to the output, channel by channel, with gain.
    /// Handles interleaved and non-interleaved buffers on either side. Runs on the
    /// real-time audio thread, so it doesn't allocate.
    static func copy(_ input: UnsafePointer<AudioBufferList>, to output: UnsafeMutablePointer<AudioBufferList>, gain: Float) {
        let inBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outBuffers = UnsafeMutableAudioBufferListPointer(output)

        // Total input channels across buffers (1 interleaved buffer or N mono buffers).
        var inputChannels = 0
        for buffer in inBuffers where buffer.mData != nil { inputChannels += max(1, Int(buffer.mNumberChannels)) }

        /// (samples, stride, frames) of the n-th input channel.
        func inputChannel(_ index: Int) -> (UnsafeMutablePointer<Float>, Int, Int)? {
            var remaining = index
            for buffer in inBuffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                let count = max(1, Int(buffer.mNumberChannels))
                if remaining < count {
                    return (data + remaining, count, Int(buffer.mDataByteSize) / MemoryLayout<Float>.size / count)
                }
                remaining -= count
            }
            return nil
        }

        var outputIndex = 0
        for buffer in outBuffers {
            guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
            let count = max(1, Int(buffer.mNumberChannels))
            let frames = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size / count
            for channel in 0..<count {
                let out = data + channel
                // More output than input channels (e.g. 4-channel device): repeat the last input channel.
                let source = inputChannels > 0 ? inputChannel(min(outputIndex, inputChannels - 1)) : nil
                let copied = min(frames, source?.2 ?? 0)
                if let (samples, stride, _) = source {
                    for frame in 0..<copied {
                        out[frame * count] = max(-1, min(1, samples[frame * stride] * gain))
                    }
                }
                for frame in copied..<frames { out[frame * count] = 0 }
                outputIndex += 1
            }
        }
    }
}
