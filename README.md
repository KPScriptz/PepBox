<p align="center">
  <img src=".github/pepbox-icon.png" alt="PepBox" width="140" />
</p>

<h1 align="center">PepBox</h1>

<p align="center">
  A notch shelf and productivity layer for macOS.<br>
  <sub>Based on <a href="https://github.com/iordv/Droppy">Droppy</a> by Jordy Spruit · GPL-3.0 + Commons Clause</sub>
</p>

---

PepBox turns the MacBook notch (or a floating bar on notchless displays) into a
shelf for files in transit, plus a clipboard manager, media controls, HUD
replacements and a set of optional extensions.

## Features

- **File shelf**: drop files, folders, images and URLs onto the notch and pick
  them up in any app. Quick Look, AirDrop, rename, zip, OCR and file conversion
  from the right-click menu.
- **Floating basket**: jiggle the mouse while dragging to spawn a basket anywhere
  on screen.
- **Clipboard manager**: searchable clipboard history.
- **Media and system HUDs**: now playing, volume, brightness, battery, AirPods,
  Caps Lock and Do Not Disturb.
- **Extensions**: window snapping, screenshot/element capture, voice
  transcription (WhisperKit), video compression (FFmpeg), menu bar manager,
  reminders, terminal and more. Each can be switched on and off on its own.

## Building

Requirements: macOS 14 (Sonoma) or later, Xcode 26 or later (the app icon uses
the Icon Composer `.icon` format).

1. Open `PepBox.xcodeproj` in Xcode.
2. Under *Signing & Capabilities*, choose your team (the project ships with no
   team set).
3. Build and run the `PepBox` scheme.
4. Optional: `./build_helper.sh` builds the `PepBoxUpdater` helper and copies it
   into `build/Release/PepBox.app`.

Swift packages (WhisperKit, SwiftTerm, SkyLightWindow) resolve automatically on
first build. `reset_dev_permissions.sh` clears the app's privacy permissions
while you're developing.

## Updates

The in-app update checker reads the latest release of `KPScriptz/PepBox` from
the GitHub API and installs the attached `.dmg`. It needs public releases (or
the repo to be public) to work. Until then, update checks fail quietly.

## Privacy

PepBox has no analytics. The upstream Droppy build reported installs, launches
and extension usage to its own backend; that code has been removed.

## License

PepBox is a modified version of Droppy and is distributed under the same
license: GPL-3.0 with the Commons Clause (see [LICENSE](LICENSE)). You can use,
modify and share it, but you can't sell it or a service whose value comes mainly
from it. See [NOTICE](NOTICE) for what was changed.

"Droppy" and its logo are trademarks of Jordy Spruit ([TRADEMARK](TRADEMARK)).
PepBox is not affiliated with the Droppy project.
