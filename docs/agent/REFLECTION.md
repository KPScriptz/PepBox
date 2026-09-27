# REFLECTION: Window Recreation Fix

## Self-Critique Checklist
- [x] **Match few-shot style?** — Yes, async pattern not needed (sync UI updates).
- [x] **MainActor correct?** — All updates via `DispatchQueue.main` or `.main` queue observers.
- [x] **Input validation?** — UserDefaults.preference with defaults.
- [x] **No retain cycles?** — `[weak self]` in all closures.
- [x] **No force-unwraps?** — None added.

## Changes Summary
| File | Change |
|------|--------|
| `NotchWindowController.swift` | Added `isRecreatingWindowsAfterUnlock` flag |
| `NotchWindowController.swift` | Modified `forceReregisterMonitors` → destroy/recreate windows on unlock |
| `NotchWindowController.swift` | Modified `createWindowForScreen` → skip SkyLight if recreating |
| `NotchWindowController.swift` | Added lock observer → re-delegate to SkyLight on lock |

## Flow
```
LOCK SCREEN ENABLED:
┌─────────────────────────────────────────────────────────────────────┐
│ App Launch                                                          │
│   → createWindowForScreen                                           │
│   → SkyLight delegateWindow (window visible on lock screen)         │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ LOCK (sessionDidResignActive)                                       │
│   → lockObserver fires                                              │
│   → delegateToLockScreen() (ensures window is visible on lock)      │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ UNLOCK (sessionDidBecomeActive)                                      │
│   → forceReregisterMonitors() after 1.0s delay                       │
│   → DESTROY zombified SkyLight-delegated windows                    │
│   → CREATE fresh windows (NOT delegated to SkyLight)                │
│   → Desktop interaction works ✓                                     │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ NEXT LOCK                                                            │
│   → lockObserver fires again                                        │
│   → Fresh window delegated to SkyLight for lock screen visibility   │
└─────────────────────────────────────────────────────────────────────┘
```
