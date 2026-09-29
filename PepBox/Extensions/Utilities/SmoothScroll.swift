//
//  SmoothScroll.swift
//  PepBox
//
//  Turns a mouse wheel's line steps into short eased pixel glides. Trackpads and
//  Magic Mouse (continuous scrolling) pass through untouched, and so does
//  everything whenever the tap can't be used.
//

import AppKit
import CoreGraphics

final class SmoothScrollController {
    static let shared = SmoothScrollController()

    /// Marks events we post so the tap lets them through.
    private static let syntheticMarker: Int64 = 0x5045_5042  // "PEPB"
    private static let pixelsPerLine: Double = 42
    /// Fraction of the remaining distance scrolled per frame (higher = snappier).
    private static let easing: Double = 0.2

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timer: DispatchSourceTimer?
    private var pendingY: Double = 0
    private var pendingX: Double = 0
    private let lock = NSLock()

    func setEnabled(_ enabled: Bool) {
        enabled ? start() : stop()
    }

    private var wantsEnabled = false

    private func start() {
        wantsEnabled = true
        guard tap == nil else { return }
        guard AXIsProcessTrusted() else {
            // The event tap needs Accessibility; start as soon as it's granted.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                if self?.wantsEnabled == true { self?.start() }
            }
            return
        }
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                let controller = Unmanaged<SmoothScrollController>.fromOpaque(info).takeUnretainedValue()
                return controller.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("🖱️ SmoothScroll: couldn't create event tap")
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.runLoopSource = source
    }

    private func stop() {
        wantsEnabled = false
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        timer?.cancel()
        timer = nil
        lock.withLock { pendingY = 0; pendingX = 0 }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .scrollWheel,
              event.getIntegerValueField(.eventSourceUserData) != Self.syntheticMarker,
              event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0,
              // Shift+wheel (sideways), Ctrl/Cmd+wheel (zoom) etc. rely on the modifier flags,
              // which the replayed pixel events wouldn't carry: leave those alone.
              event.flags.intersection([.maskShift, .maskControl, .maskCommand, .maskAlternate]).isEmpty else {
            return Unmanaged.passUnretained(event)
        }

        let lines = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        let columns = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        guard lines != 0 || columns != 0 else { return Unmanaged.passUnretained(event) }

        lock.withLock {
            // Reversing direction cancels the leftover glide instead of fighting it.
            if lines != 0, (lines > 0) != (pendingY > 0) { pendingY = 0 }
            if columns != 0, (columns > 0) != (pendingX > 0) { pendingX = 0 }
            pendingY += lines * Self.pixelsPerLine
            pendingX += columns * Self.pixelsPerLine
        }
        startTimerIfNeeded()
        return nil  // swallow the line step; the timer delivers it as pixels
    }

    private static func step(_ delta: Double, remaining: Double) -> Int32 {
        let rounded = Int32(delta.rounded())
        if rounded == 0 && abs(remaining) >= 0.5 { return remaining > 0 ? 1 : -1 }
        return rounded
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(8))
        timer.setEventHandler { [weak self] in self?.step() }
        timer.resume()
        self.timer = timer
    }

    private func step() {
        let (y, x): (Int32, Int32) = lock.withLock {
            // Ease toward the target; finish the last pixel instead of crawling toward zero.
            let dy = abs(pendingY) < 1 ? pendingY : pendingY * Self.easing
            let dx = abs(pendingX) < 1 ? pendingX : pendingX * Self.easing
            // Always move at least a pixel while distance remains, or the glide never ends.
            let y = Self.step(dy, remaining: pendingY), x = Self.step(dx, remaining: pendingX)
            // Subtract exactly what's posted so the total distance is preserved.
            pendingY -= Double(y)
            pendingX -= Double(x)
            return (y, x)
        }
        if y != 0 || x != 0,
           let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: y, wheel2: x, wheel3: 0) {
            event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticMarker)
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            event.post(tap: .cgSessionEventTap)
        }
        let done = lock.withLock { abs(pendingY) < 0.5 && abs(pendingX) < 0.5 }
        if done {
            lock.withLock { pendingY = 0; pendingX = 0 }
            timer?.cancel()
            timer = nil
        }
    }
}
