# VERIFICATION: Auto-Expand Fix

## Changes Implemented
1. **NotchWindowController.swift**:
   - `forceReregisterMonitors`: Added robust reset logic.
     - Stops/Starts monitors.
     - Restores `window.level`.
     - Toggles `ignoresMouseEvents` off/on/off to reset hit-testing.
     - Retries global monitor start if failed.
   - `setupSystemObservers`: Increased unlock delay from 0.3s to 1.0s.

## Test Cases

### 1. Basic Auto-Expand (Baseline)
- [ ] Hover notch -> Expands.
- [ ] Move away -> Collapses.

### 2. Lock/Unlock Cycle (The Fix)
- [ ] Lock screen (`Cmd+Ctrl+Q`).
- [ ] Verify Notch is visible on Lock Screen (media widget).
- [ ] Unlock.
- [ ] Wait 1 second (log: "🔓 NotchWindowController: Screen unlocked...").
- [ ] Hover notch immediately.
- [ ] **Expected**: Notch expands.
- [ ] **Previous Failure**: Notch ignored mouse.

### 3. Repeated Cycles
- [ ] Repeat step 2 three times.
- [ ] Ensure no degradation (e.g. flickering, failure to expand).

### 4. Fullscreen Interaction
- [ ] Enter fullscreen app.
- [ ] Lock/Unlock.
- [ ] Exit fullscreen.
- [ ] Hover notch -> check expand.

## Automated Verification
N/A - Requires physical user action (Lock/Unlock).
