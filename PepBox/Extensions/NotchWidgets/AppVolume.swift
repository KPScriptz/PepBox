//
//  AppVolume.swift
//  PepBox
//
//  Per-app volume with Core Audio process taps (macOS 14.2+). While an app's
//  level isn't 100%, PepBox taps its audio (muting the original), scales it and
//  plays it on the current output device through a private aggregate device.
//  At 100% the tap is removed, so untouched apps keep their normal audio path.
//

import SwiftUI
import AppKit
import CoreAudio
import AudioToolbox
import Combine

/// One app as shown in the panel: its own audio process plus any helpers
/// (e.g. browser renderers) that play sound on its behalf.
struct AudioApp: Identifiable, Hashable {
    /// Parent app bundle ID, or "pid:<n>" for apps without one.
    let id: String
    let name: String
    let iconPID: pid_t
    let objectIDs: [AudioObjectID]

    var icon: NSImage? { NSRunningApplication(processIdentifier: iconPID)?.icon }
}

@Observable
final class AppVolumeManager {
    static let shared = AppVolumeManager()

    /// Apps currently playing sound, plus any app whose level was changed.
    private(set) var apps: [AudioApp] = []
    /// 0...1.5 per app; missing = 100%.
    private(set) var levels: [String: Float] = [:]
    private(set) var errorMessage: String?

    private var taps: [String: Any] = [:]  // AppAudioTap, stored as Any to avoid availability on the property
    /// Process set each tap was built for, to rebuild it when an app starts a new helper.
    private var tappedObjects: [String: Set<AudioObjectID>] = [:]

    var isSupported: Bool {
        if #available(macOS 14.2, *) { return true }
        return false
    }

    func level(for app: AudioApp) -> Float { levels[app.id] ?? 1 }

    func refresh() {
        let groups = Self.audioApps()
        apps = groups.filter { $0.isPlaying || levels[$0.app.id] != nil }
            .map(\.app)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let byID = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
        for (id, level) in levels {
            guard let app = byID[id] else {
                setLevel(1, for: id, objectIDs: [])  // app quit
                continue
            }
            // A new helper started playing: rebuild the tap so it's included.
            if tappedObjects[id] != Set(app.objectIDs) {
                removeTap(id)
                setLevel(level, for: id, objectIDs: app.objectIDs)
            }
        }
    }

    func setLevel(_ level: Float, for app: AudioApp) {
        setLevel(level, for: app.id, objectIDs: app.objectIDs)
    }

    /// Puts every app back to its normal audio path.
    func resetAll() {
        for id in Array(levels.keys) { setLevel(1, for: id, objectIDs: []) }
    }

    private var outputListenerInstalled = false

    /// Taps play through the output device that was current when they were made, so rebuild
    /// them when the user switches outputs (e.g. to AirPods) instead of leaving apps on the old one.
    private func followDefaultOutputChanges() {
        guard !outputListenerInstalled else { return }
        outputListenerInstalled = true
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, .main) { [weak self] _, _ in
            self?.rebuildAllTaps()
        }
    }

    private func rebuildAllTaps() {
        let current = levels
        let byID = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
        for (id, level) in current {
            removeTap(id)
            setLevel(level, for: id, objectIDs: byID[id]?.objectIDs ?? [])
        }
    }

    private func removeTap(_ id: String) {
        guard #available(macOS 14.2, *) else { return }
        (taps[id] as? AppAudioTap)?.stop()
        taps[id] = nil
        tappedObjects[id] = nil
    }

    private func setLevel(_ level: Float, for id: String, objectIDs: [AudioObjectID]) {
        guard #available(macOS 14.2, *) else { return }
        let clamped = min(1.5, max(0, level))
        errorMessage = nil

        if abs(clamped - 1) < 0.01 {
            // Back to normal: remove the tap entirely.
            removeTap(id)
            levels[id] = nil
            return
        }

        levels[id] = clamped
        if let tap = taps[id] as? AppAudioTap {
            tap.gain = clamped
            return
        }
        guard !objectIDs.isEmpty else { return }
        followDefaultOutputChanges()
        do {
            let tap = try AppAudioTap(processObjectIDs: objectIDs, name: "PepBox App Volume \(id)")
            tap.gain = clamped
            taps[id] = tap
            tappedObjects[id] = Set(objectIDs)
        } catch {
            levels[id] = nil
            errorMessage = "Couldn't change this app's volume. Allow PepBox under Privacy & Security → Screen & System Audio Recording."
            print("🔊 AppVolume: \(error)")
        }
    }

    // MARK: - Core Audio process list

    private struct Group {
        var app: AudioApp
        var isPlaying: Bool
    }

    /// Audio processes grouped under the app they belong to.
    private static func audioApps() -> [Group] {
        let ids: [AudioObjectID] = getArray(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList)
        let ownPID = Foundation.ProcessInfo.processInfo.processIdentifier
        let regularApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }

        var groups: [String: Group] = [:]
        var order: [String] = []
        for objectID in ids {
            guard let pid: pid_t = getValue(objectID, kAudioProcessPropertyPID), pid != ownPID else { continue }
            let bundleID = stringValue(objectID, kAudioProcessPropertyBundleID)
                ?? NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
            // Helpers carry the parent's bundle ID as a prefix (com.google.Chrome.helper.Renderer).
            let parent = bundleID.flatMap { id in
                regularApps
                    .filter { app in app.bundleIdentifier.map { id == $0 || id.hasPrefix($0 + ".") } ?? false }
                    .max { ($0.bundleIdentifier?.count ?? 0) < ($1.bundleIdentifier?.count ?? 0) }
            }
            let owner = parent ?? NSRunningApplication(processIdentifier: pid)
            guard let owner else { continue }
            let key = owner.bundleIdentifier ?? "pid:\(owner.processIdentifier)"
            let playing: UInt32 = getValue(objectID, kAudioProcessPropertyIsRunningOutput) ?? 0

            if var group = groups[key] {
                group.app = AudioApp(id: key, name: group.app.name, iconPID: group.app.iconPID,
                                     objectIDs: group.app.objectIDs + [objectID])
                group.isPlaying = group.isPlaying || playing != 0
                groups[key] = group
            } else {
                order.append(key)
                // Safari and other WebKit views play through a shared WebKit process.
                let name = key.hasPrefix("com.apple.WebKit")
                    ? "Safari & Web Views"
                    : owner.localizedName ?? owner.bundleIdentifier ?? "PID \(owner.processIdentifier)"
                groups[key] = Group(
                    app: AudioApp(id: key, name: name, iconPID: owner.processIdentifier, objectIDs: [objectID]),
                    isPlaying: playing != 0
                )
            }
        }
        return order.compactMap { groups[$0] }
    }
}

// MARK: - Core Audio helpers

private func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
}

private func getValue<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> T? {
    var addr = address(selector)
    var size = UInt32(MemoryLayout<T>.size)
    let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
    defer { pointer.deallocate() }
    guard AudioObjectGetPropertyData(object, &addr, 0, nil, &size, pointer) == noErr else { return nil }
    return pointer.pointee
}

private func getArray<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [T] {
    var addr = address(selector)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(object, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
    let count = Int(size) / MemoryLayout<T>.stride
    return Array(unsafeUninitializedCapacity: count) { buffer, initialized in
        var dataSize = size
        let status = AudioObjectGetPropertyData(object, &addr, 0, nil, &dataSize, buffer.baseAddress!)
        initialized = status == noErr ? Int(dataSize) / MemoryLayout<T>.stride : 0
    }
}

private func stringValue(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
    var addr = address(selector)
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value) == noErr else { return nil }
    let string = value?.takeRetainedValue() as String?
    return string?.isEmpty == false ? string : nil
}

private func deviceUID(_ device: AudioObjectID) -> String? {
    var addr = address(kAudioDevicePropertyDeviceUID)
    var uid: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &uid) == noErr else { return nil }
    return uid?.takeRetainedValue() as String?
}

enum AppAudioTapError: Error {
    case noOutputDevice
    case tap(OSStatus)
    case aggregate(OSStatus)
    case ioProc(OSStatus)
    case start(OSStatus)
}

/// One tapped app: process tap (original muted) → aggregate device → IOProc applying gain → output.
@available(macOS 14.2, *)
final class AppAudioTap {
    /// Read on the audio thread; a plain Float store is fine for a volume level.
    var gain: Float = 1

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "com.pepbox.appvolume", qos: .userInteractive)

    init(processObjectIDs: [AudioObjectID], name: String) throws {
        guard let outputDevice: AudioObjectID = getValue(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice),
              let outputUID = deviceUID(outputDevice) else { throw AppAudioTapError.noOutputDevice }

        let description = CATapDescription(stereoMixdownOfProcesses: processObjectIDs)
        description.uuid = UUID()
        description.muteBehavior = .mutedWhenTapped
        description.isPrivate = true
        description.name = name

        var status = AudioHardwareCreateProcessTap(description, &tapID)
        guard status == noErr else { throw AppAudioTapError.tap(status) }

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: name,
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: description.uuid.uuidString
            ]]
        ]
        status = AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID)
        guard status == noErr else {
            stop()
            throw AppAudioTapError.aggregate(status)
        }

        status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { [weak self] _, input, _, output, _ in
            Self.copy(input, to: output, gain: self?.gain ?? 1)
        }
        guard status == noErr else {
            stop()
            throw AppAudioTapError.ioProc(status)
        }

        status = AudioDeviceStart(aggregateID, procID)
        guard status == noErr else {
            stop()
            throw AppAudioTapError.start(status)
        }
    }

    deinit { stop() }

    /// Tears everything down; the app's audio goes back to normal once the tap is destroyed.
    func stop() {
        if aggregateID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
        }
        procID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    /// Copies Float32 samples from the tap to the output, channel by channel, with gain.
    /// Handles interleaved and non-interleaved buffers on either side. Runs on the
    /// real-time audio thread, so it doesn't allocate.
    private static func copy(_ input: UnsafePointer<AudioBufferList>, to output: UnsafeMutablePointer<AudioBufferList>, gain: Float) {
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

// MARK: - Panel

struct AppVolumeNotchView: View {
    var manager: AppVolumeManager
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !manager.isSupported {
                Text("Per-app volume needs macOS 14.2 or later.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            } else if manager.apps.isEmpty {
                Text("Apps playing sound show up here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(manager.apps) { app in
                            row(app)
                        }
                    }
                }
            }
            if let message = manager.errorMessage {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .onAppear { manager.refresh() }
        .onReceive(timer) { _ in manager.refresh() }
    }

    private func row(_ app: AudioApp) -> some View {
        let level = manager.level(for: app)
        return HStack(spacing: 10) {
            Group {
                if let icon = app.icon {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: "app").resizable().foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: 22, height: 22)
            Text(app.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: 96, alignment: .leading)
            Slider(value: Binding(get: { Double(level) }, set: { manager.setLevel(Float($0), for: app) }), in: 0...1.5)
                .controlSize(.small)
            Text("\(Int((level * 100).rounded()))%")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(level == 1 ? .white.opacity(0.5) : .white)
                .frame(width: 40, alignment: .trailing)
                .onTapGesture { manager.setLevel(1, for: app) }
                .help("Click to reset to 100%")
        }
    }
}
