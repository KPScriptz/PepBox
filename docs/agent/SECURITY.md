# SECURITY: Auto-Expand Fix

## Audit Summary
- **Force Unwraps**: None introduced. `Int(CGShieldingWindowLevel())` is safe as `CGWindowLevel` is `Int32`.
- **Input Validation**: N/A (Internal state management).
- **Permissions**: Uses existing `NSEvent.addGlobalMonitor` which requires Accessibility permissions. Code gracefully handles nil return (implied by `retry`).
- **Main Actor**: All UI updates in `forceReregisterMonitors` are called from `NotificationCenter` observers on `.main` queue or `DispatchQueue.main`, ensuring thread safety.

## Risks
- **Privacy**: Does not log mouse coordinates.
- **Access**: Global monitor is passive (read-only).
