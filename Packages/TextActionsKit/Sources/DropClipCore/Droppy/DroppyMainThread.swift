//
//  DroppyMainThread.swift
//  DropClip, inside Droppy
//
//  `MainActor.assumeIsolated`, without asking the concurrency runtime.
//

import Foundation

/// Droppy: inside Droppy on macOS 27, AppKit and Carbon callouts (timers, event monitors,
/// notification blocks, hotkey handlers) can reach Swift with the current-executor bookkeeping
/// holding a stale reference, and `assumeIsolated`'s own check crashes on it before the body
/// runs. Droppy bridges its callouts the same way (`makeMainThreadTimerHandler`): assert the
/// main thread, which is the invariant that matters,
/// and run the body as the synchronous function it is. One copy per target, since each is its
/// own module; the port from OpenClip (PROVENANCE.md) rewrites upstream's calls to it.
enum DroppyMainThread {
    nonisolated static func enter<T>(
        _ body: @MainActor () throws -> T, file: StaticString = #fileID, line: UInt = #line
    ) rethrows -> T {
        precondition(Thread.isMainThread, "Main-actor callout off the main thread", file: file, line: line)
        return try withoutActuallyEscaping(body) { escapable in
            try unsafeBitCast(escapable, to: (() throws -> T).self)()
        }
    }
}
