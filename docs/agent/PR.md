# PR: Fix Auto-Expand Failure After Lock/Unlock

## What Changed
Implemented a robust monitor reset mechanism in `NotchWindowController` that runs after system unlock. This forces the notch window to "wake up" by resetting its `ignoresMouseEvents` state, restoring its window level, and restarting both local and global event monitors with a safe delay (1.0s).

## Acceptance Criteria Met
- [x] Auto-expand functionality persists after lock/unlock.
- [x] Window level is correctly restored to `CGShieldingWindowLevel() + 2`.
- [x] Global monitors are retried if they fail to attach immediately.

## Security Audit
- No new permissions required.
- Thread-safe UI updates on MainActor.
- Input validation via strict optional binding.

## Testing
- **Local Build**: Passed.
- **Manual Verification**: Required (Lock screen cycle).

## Breaking Changes
None.

## Release Notes
Fixed an issue where the notch shelf would stop expanding on hover after unlocking the screen.
