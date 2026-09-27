# SPEC: Fix Auto-Expand Failure After SkyLight Lock Screen Delegation

## Purpose
Restore notch interactivity (auto-expand/collapse) on the desktop after unlocking. The SkyLight delegation used for lock screen visibility permanently compromises window event handling.

## Root Cause Analysis
```
THINKING:
- User confirms: "on an older version this wasn't the case" (before SkyLight integration)
- In `createWindowForScreen` (line 235-246): Window is delegated to SkyLight immediately if lock screen setting is ON
- SkyLight moves window to `NotificationCenterAtScreenLock` space (level 400)
- After unlock, window remains in corrupted state - can't receive mouse events properly
- Previous fix attempts (resetting ignoresMouseEvents, window level) failed
- Conclusion: SkyLight delegation is IRREVERSIBLE for event handling purposes
```

## Solution: Window Recreation Strategy
**On Unlock**: Destroy SkyLight-delegated windows → Create fresh windows (not delegated)
**On Lock**: Re-delegate the fresh windows to SkyLight for lock screen visibility

## Implementation Location
- `NotchWindowController.swift`
- Modify `forceReregisterMonitors()` (called on unlock)
- Add lock observer to re-delegate windows

## Acceptance Criteria
- [ ] After unlock, notch expands on hover
- [ ] After unlock, notch collapses when mouse leaves
- [ ] Lock screen still shows notch (when setting enabled)
- [ ] 3x lock/unlock cycles work consistently
- [ ] No visible flicker during window recreation (or minimal)
- [ ] External monitors unaffected (SkyLight only applies to built-in)

## Risks
- **State Loss**: Window-local state reset on recreation (acceptable - hover state should reset anyway)
- **Timing**: Race between recreation and user interaction (mitigated by 1.0s delay)
