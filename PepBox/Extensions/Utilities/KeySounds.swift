//
//  KeySounds.swift
//  PepBox
//
//  Mechanical keyboard sounds while typing. The clicks are synthesized at start-up
//  (noise transient + low body), so no audio files are bundled.
//

import AppKit
import AVFoundation
import Carbon.HIToolbox

final class KeySoundsManager {
    static let shared = KeySoundsManager()

    static let volumeKey = "keySounds_volume"

    private let engine = AVAudioEngine()
    private let players: [AVAudioPlayerNode] = (0..<6).map { _ in AVAudioPlayerNode() }
    private var nextPlayer = 0
    private var clickBuffers: [AVAudioPCMBuffer] = []
    private var thockBuffer: AVAudioPCMBuffer?
    private var isEngineSetUp = false

    private var globalMonitor: Any?
    /// Stops the engine after a pause in typing so the audio device (and Bluetooth
    /// headphones) can go idle instead of staying active the whole time.
    private var idleStop: DispatchWorkItem?
    private var localMonitor: Any?

    var volume: Float {
        get {
            let saved = UserDefaults.standard.object(forKey: Self.volumeKey) as? Float
            return saved ?? 0.5
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.volumeKey)
            engine.mainMixerNode.outputVolume = newValue
        }
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            guard globalMonitor == nil else { return }
            setUpEngineIfNeeded()
            // Global monitor = typing in other apps (needs Accessibility / Input Monitoring);
            // local monitor = typing in PepBox itself.
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.play(for: event)
            }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.play(for: event)
                return event
            }
        } else {
            if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
            if let localMonitor { NSEvent.removeMonitor(localMonitor) }
            globalMonitor = nil
            localMonitor = nil
            idleStop?.cancel()
            idleStop = nil
            if isEngineSetUp { engine.stop() }
        }
    }

    private func play(for event: NSEvent) {
        guard !event.isARepeat else { return }
        let isBigKey = [kVK_Space, kVK_Return, kVK_Delete, kVK_Tab].contains(Int(event.keyCode))
        guard let buffer = isBigKey ? thockBuffer : clickBuffers.randomElement() else { return }
        if !engine.isRunning { try? engine.start() }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }

        idleStop?.cancel()
        let stop = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.players.forEach { $0.stop() }
            self.engine.pause()
        }
        idleStop = stop
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: stop)
    }

    private func setUpEngineIfNeeded() {
        guard !isEngineSetUp else { return }
        isEngineSetUp = true
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        for player in players {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        engine.mainMixerNode.outputVolume = volume
        // A few slightly different clicks so fast typing doesn't sound robotic.
        clickBuffers = [(3_600.0, 0.018), (4_200.0, 0.015), (3_000.0, 0.02)].compactMap { tone, decay in
            Self.makeClick(format: format, clickTone: tone, clickDecay: decay, bodyFrequency: 190, bodyLevel: 0.35)
        }
        thockBuffer = Self.makeClick(format: format, clickTone: 2_200, clickDecay: 0.025, bodyFrequency: 110, bodyLevel: 0.6)
    }

    /// Short filtered-noise transient plus a decaying low sine "body".
    private static func makeClick(format: AVAudioFormat, clickTone: Double, clickDecay: Double,
                                  bodyFrequency: Double, bodyLevel: Double) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount(sampleRate * 0.09)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames

        var lowPassed = 0.0
        let smoothing = min(1, clickTone / sampleRate * 2 * .pi)
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let attack = min(1, t / 0.0008)
            lowPassed += (Double.random(in: -1...1) - lowPassed) * smoothing
            let click = lowPassed * exp(-t / clickDecay) * attack
            let body = sin(2 * .pi * bodyFrequency * t) * exp(-t / 0.03) * bodyLevel * attack
            samples[i] = Float((click * 0.9 + body) * 0.6)
        }
        return buffer
    }
}
