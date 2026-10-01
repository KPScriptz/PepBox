// ExtensionsDirectoryWatcher.swift
// DropClip
//
// Watches ~/.dropclip/extensions for add/remove/edit changes and hot-reloads the loaded
// extension actions (new installs, uninstalls, and manifest edits appear without relaunch).
//
// FSEvents starts a snapshot comparison only when something changes. Two matching snapshots
// settle a write before reloading, so package copies cannot trigger a half-written reload and
// an unchanged extensions folder needs no recurring enumeration or timer.
import CoreServices
import Foundation
import DropClipCore

/// Immutable fingerprint of a directory tree. Two equal snapshots mean no file changed.
struct ExtensionsSnapshot: Equatable {
    /// Relative file path (from the watched root) -> content modification date.
    let files: [String: Date]

    /// Recursively fingerprints every non-hidden file under `root`.
    /// Returns `nil` if the directory does not exist or is unreadable.
    /// Hidden items are skipped, matching `uninstallExtension`'s convention of ignoring
    /// `.install_staging_*` dirs and dotfiles .DS_Store left behind by installs.
    static func build(from root: URL) -> ExtensionsSnapshot? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue,
              let enumerator = FileManager.default.enumerator(
                  at: root,
                  includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                  options: [.skipsHiddenFiles]
              ) else { return nil }

        let rootPath = root.standardizedFileURL.path
        var files: [String: Date] = [:]
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey]),
                  values.isDirectory != true,
                  let date = values.contentModificationDate else { continue }
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(rootPath + "/") else { continue }
            let relativePath = String(path.dropFirst(rootPath.count + 1))
            files[relativePath] = date
        }
        return ExtensionsSnapshot(files: files)
    }
}

/// Diffs snapshots after filesystem events and reloads after a change settles.
/// Filesystem work runs on a private queue; the reload closure runs on the MainActor.
final class ExtensionsDirectoryWatcher: @unchecked Sendable {
    /// Delay between the two snapshots that settle an actual filesystem change.
    static let defaultPollInterval: TimeInterval = 1.0

    private let queue = DispatchQueue(label: "com.dropclip.extensions.watch")
    private var stream: FSEventStreamRef?
    private var settleWork: DispatchWorkItem?
    private var interval: TimeInterval = defaultPollInterval
    private var generation = 0

    /// The stream retains this context, without retaining its owner through the callback.
    private final class Context {
        weak var owner: ExtensionsDirectoryWatcher?
        init(owner: ExtensionsDirectoryWatcher) { self.owner = owner }
    }

    /// Invoked on the MainActor when the directory tree settles into a new state.
    private let reload: @MainActor () async -> Void

    // State below is confined to `queue`.
    private var root: URL?
    private var lastSeen: ExtensionsSnapshot?
    private var pending: ExtensionsSnapshot?
    private var reloadInFlight = false
    private var needsReload = false

    init(reload: @escaping @MainActor () async -> Void) {
        self.reload = reload
    }

    deinit {
        settleWork?.cancel()
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }

    func start(watching root: URL, interval: TimeInterval = ExtensionsDirectoryWatcher.defaultPollInterval) {
        queue.async { [weak self] in
            guard let self, self.stream == nil else { return }
            self.generation &+= 1
            self.root = root.standardizedFileURL
            self.interval = max(0.1, interval)
            self.lastSeen = ExtensionsSnapshot.build(from: root)
            self.pending = nil
            self.needsReload = false
            let contextOwner = Context(owner: self)
            var context = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passUnretained(contextOwner).toOpaque(),
                retain: { pointer in
                    guard let pointer else { return nil }
                    return UnsafeRawPointer(Unmanaged<Context>.fromOpaque(pointer).retain().toOpaque())
                },
                release: { pointer in
                    guard let pointer else { return }
                    Unmanaged<Context>.fromOpaque(pointer).release()
                },
                copyDescription: nil
            )
            let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
                guard let info,
                      let owner = Unmanaged<Context>.fromOpaque(info).takeUnretainedValue().owner,
                      let root = owner.root else { return }
                let paths = UnsafeRawPointer(paths).assumingMemoryBound(to: UnsafePointer<CChar>?.self)
                let rootPath = root.path
                for index in 0..<count {
                    let dropped = flags[index] & UInt32(
                        kFSEventStreamEventFlagMustScanSubDirs
                            | kFSEventStreamEventFlagUserDropped
                            | kFSEventStreamEventFlagKernelDropped) != 0
                    let path = paths[index].map { String(cString: $0) }
                    if dropped || path == rootPath || path?.hasPrefix(rootPath + "/") == true {
                        owner.scheduleSnapshot()
                        break
                    }
                }
            }
            // Watching the parent also catches replacement or recreation of the root folder.
            let createdStream = withExtendedLifetime(contextOwner) {
                FSEventStreamCreate(
                    kCFAllocatorDefault, callback, &context,
                    [root.deletingLastPathComponent().path] as CFArray,
                    FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.25,
                    FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
                )
            }
            guard let stream = createdStream else {
                Log.extensions.error("Could not create the extensions filesystem watcher")
                return
            }
            FSEventStreamSetDispatchQueue(stream, self.queue)
            guard FSEventStreamStart(stream) else {
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
                Log.extensions.error("Could not start the extensions filesystem watcher")
                return
            }
            self.stream = stream
            self.scheduleSnapshot()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.generation &+= 1
            self.settleWork?.cancel()
            self.settleWork = nil
            if let stream = self.stream {
                FSEventStreamStop(stream)
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
            }
            self.stream = nil
            self.root = nil
            self.lastSeen = nil
            self.pending = nil
            self.needsReload = false
        }
    }

    /// Runs a single poll tick synchronously on the watch queue. Exposed so tests can drive
    /// the settle logic without waiting on the live timer.
    func pollOnce() {
        queue.sync { [weak self] in
            self?.poll()
        }
    }

    /// Coalesces event bursts. A settled tree schedules nothing until its next event.
    private func scheduleSnapshot() {
        guard root != nil, settleWork == nil else { return }
        let generation = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self, generation == self.generation, self.root != nil else { return }
            self.settleWork = nil
            self.poll()
        }
        settleWork = work
        queue.asyncAfter(deadline: .now() + interval, execute: work)
    }

    /// Runs on `queue` only.
    private func poll() {
        guard let root else { return }
        guard let current = ExtensionsSnapshot.build(from: root) else {
            // Directory missing or unreadable: don't reload. A transient state (e.g. a package
            // deleted mid-replacement) shouldn't wipe the registry.
            return
        }
        if current == lastSeen {
            pending = nil
            return
        }
        guard let pending else {
            // First differing tick: remember it and wait for a second agreeing tick.
            self.pending = current
            scheduleSnapshot()
            return
        }
        guard pending == current else {
            // Still settling (kept changing since the last tick); slide the reference forward.
            self.pending = current
            scheduleSnapshot()
            return
        }
        // Two consecutive ticks agree on the changed tree → settled.
        lastSeen = current
        self.pending = nil
        guard !reloadInFlight else {
            // A reload is already running; remember that another is needed and run it once
            // the in-flight one completes (see reloadCompleted). This keeps concurrent
            // loadExtensions runs from racing the registry's register/unregister.
            needsReload = true
            return
        }
        Log.extensions.notice("Extensions directory changed; reloading extensions")
        dispatchReload()
    }

    /// Starts a reload task on the MainActor. Called from `queue` so the in-flight flags stay confined.
    private func dispatchReload() {
        reloadInFlight = true
        Task { @MainActor [weak self] in
            await self?.reload()
            self?.reloadCompleted()
        }
    }

    /// Runs on the MainActor (after `reload`). Hops back to `queue` to clear the in-flight flag
    /// and fire the deferred reload, if any change settled while the previous one was running.
    private func reloadCompleted() {
        queue.async { [weak self] in
            guard let self else { return }
            self.reloadInFlight = false
            guard self.root != nil, self.needsReload else { return }
            self.needsReload = false
            Log.extensions.notice("Extensions directory changed while reloading; reloading again")
            self.dispatchReload()
        }
    }
}
