# Provenance

DropClip is Droppy's fork of OpenClip, Ganesh M's text utility. Until 2.0.5 this droplet was
called OpenClip and was made with its author; from 2.1.0 it is DropClip, maintained by Droppy
alone.

| Target | Taken from | Licence |
|---|---|---|
| `Sources/DropClip` | OpenClip `Sources/OpenClip` at `7919d76` (2026-09-23) | MIT |
| `Sources/DropClipCore` | OpenClip `Sources/Core` at `7919d76` (2026-09-23) | MIT |
| `Sources/OpenSelection` | OpenSelection `Sources/OpenSelection` at `95a8900` (2026-09-23) | Apache-2.0 |

## Frozen on purpose

OpenClip relicensed from MIT to the GNU AGPL v3 on 2026-09-25 (its commit `b9d19bc`). Everything
here was taken before that, from `7919d76`, and stays under the MIT License: a licence already
granted cannot be taken back, and OpenClip's own NOTICE says copies obtained under MIT remain
governed by MIT.

**Never bring in anything from OpenClip after `b9d19bc`.** Not a sync, not a cherry-pick, not a
fix copied by hand. Code from after the relicense is AGPL, somebody else's AGPL code linked into
a droplet that runs in Droppy's process would bring the AGPL's terms to that combined work, and
DropClip would have to become AGPL itself. The script that used to sync
from upstream is gone for that reason. A bug in DropClip is fixed here, from scratch.

OpenSelection is a separate library and is still Apache-2.0; a newer OpenSelection may be taken
if its licence is still Apache-2.0 when it is taken.

## What the licences ask, and where it is done

- **MIT (DropClip, from OpenClip):** the copyright line and licence text go with every copy,
  compiled ones included: [LICENSE](LICENSE) here, `Assets/Legal/DropClip-LICENSE.txt` in the
  built droplet.
- **Apache-2.0 (OpenSelection):** its licence and NOTICE ship (`Sources/OpenSelection/`, and
  `Assets/Legal/` in the built droplet), and each file Droppy changed says so at its top
  (`CursorClassifier.swift`, `OpenSelectionMonitor.swift`).
- **MIT (KeyboardShortcuts API by Sindre Sorhus):** `Assets/Legal/KeyboardShortcuts-LICENSE.txt`,
  credited in `Sources/DropClip/Droppy/KeyboardShortcuts.swift`.
- `Assets/Legal/Acknowledgements.txt` lists all of it; DropClip's License button opens it.

Audit, 2026-09-27: every line of `Sources/DropClip` and `Sources/DropClipCore` compared with
OpenClip's history (identifiers normalised). None of the 195 lines OpenClip has only after the
relicense appear here; the lines not in `7919d76` are Droppy's own host layer and patches.

## Names

"OpenClip" and its logo are the OpenClip project's marks. DropClip uses neither: its name, icon,
settings domain (`app.getdroppy.droplet.dropclip`), data folder (`~/.dropclip`), URL scheme
(`dropclip://`), module names and every string it shows are its own. OpenClip is named only where
DropClip credits its origin, and in the few places DropClip stays compatible with what people
made for OpenClip:

- An extension package's `openclip.json` manifest and its `minOpenClipVersion` key are read.
- Scripts see every `DROPCLIP_` variable under its old `OPENCLIP_` name too.
- JavaScript extensions find the host object as `openclip` as well as `dropclip`.
- On the first start, the OpenClip droplet's settings (`app.getdroppy.droplet.openclip`) and
  `~/.openclip` are copied over (`DropClipMigration`).

## Services

DropClip calls none of OpenClip's servers. OpenClip's online extension catalog and its extension
downloads are switched off (`ExtensionsAPIClient` has no server, `RemoteExtensionInstaller`
allows no host), so the Store page is not listed and extensions install from a file. OpenClip's
website, donation and issue links are replaced by Droppy's.

## What Droppy changed

Everything the droplet changed while it was OpenClip still applies (the host layer in each
`Droppy/` folder, the popup on Droppy's Dynamic Glass, native Settings pages, shortcuts on Droppy's
Shortcuts page, no menu bar item, updater or login item of its own). Rules the port applied to
every file:

- `import Core` is `import DropClipCore`; `Bundle.main` is `Bundle.dropclip`, the droplet's own
  bundle; `UserDefaults.standard` is `UserDefaults.dropclip`.
- `MainActor.assumeIsolated {` is `DroppyMainThread.enter {`: inside Droppy on macOS 27 the
  runtime's own check can crash at an AppKit or Carbon callout.
- `import KeyboardShortcuts`, `import SDWebImage*` and `import Sparkle` go: a droplet links
  DroppyKit and nothing else. The host layer declares the parts DropClip uses.
- `OpenClipApp.swift`, `AppDelegate.swift` and `Platform/AppUpdateManager.swift` are left out;
  the host layer is the delegate and the Droplet Store is the updater.
