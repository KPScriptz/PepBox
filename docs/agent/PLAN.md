# PLAN: Fix Auto-Expand via Window Recreation

## Goal
Fix auto-expand failure after unlock by recreating the "zombified" Notch Window and restoring lock screen delegation on subsequent locks.

## Implementation Steps

### 1. Update `forceReregisterMonitors` (NotchWindowController.swift)
- **Concept**: Remove "Repair" logic, replace with "Destroy & Recreate".
- **Steps**:
  - `stopMonitors()`
  - Close all `notchWindows`
  - `notchWindows.removeAll()`
  - `repositionNotchWindow()` (This recreates windows for current screens)
  - `startMonitors()`
  - Retain the 1.0s delay from previous phase.

### 2. Add Lock Observer (NotchWindowController.swift)
- **Location**: `setupSystemObservers`
- **Event**: `NSWorkspace.sessionDidResignActiveNotification`
- **Action**:
  - Check `UserPreferences.enableLockScreenMediaWidget` (or similar key).
  - If true: Call `self.delegateToLockScreen()`.
  - This ensures the fresh window created after unlock gets pushed to the lock screen when the user locks again.

### 3. Verify delegateToLockScreen Checks
- Ensure `delegateToLockScreen` is safe to call repeatedly (it is).

## Test Strategy
1.  **Unlock Fix**: Lock -> Unlock -> Wait 1s -> Verify Notch expands. (Passes if window is fresh).
2.  **Lock Fix**: Lock again -> Verify Notch is visible on Lock Screen.
3.  **Cycle**: Repeat 3x.

## Rollback Plan
- Revert `NotchWindowController.swift`.
