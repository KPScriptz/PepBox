<p align="center">
  <img src=".github/pepbox-icon.png" alt="PepBox" width="140" />
</p>

<h1 align="center">PepBox</h1>

<p align="center">
  <b>The native productivity layer macOS is missing.</b><br>
  <sub>100% Swift · Based on <a href="https://github.com/iordv/Droppy">Droppy</a> by Jordy Spruit · GPL-3.0 + Commons Clause</sub>
</p>

<p align="center">
  <a href="https://github.com/KPScriptz/PepBox/releases/latest"><img src="assets/download-macos.png" alt="Download for macOS" width="200" /></a>
</p>

---

<h2 align="left">Core Features</h2>

<h3 align="center">File Shelf</h3>

<p align="center"><img src="docs/assets/images/feature-shelf.png" width="500" alt="File Shelf" /></p>

- Drop files, folders, images, and URLs onto the notch — pick them up in any app
- Create folders, pin favorites, or watch a directory so its contents appear automatically
- Right-click for Copy, Move, Share, AirDrop, Rename, Quick Look, OCR, and more
- Quickshare: upload any file and get a shareable link in one click
- ZIP and Unzip files directly from the shelf
- Convert between dozens of file types — images, videos, audio, documents

---

<h3 align="center">Floating Basket</h3>

<p align="center"><img src="docs/assets/images/feature-basket.png" width="500" alt="Floating Basket" /></p>

- Jiggle your mouse while dragging to spawn a floating basket anywhere on screen
- Multiple color-coded baskets for organizing different workflows
- Cmd+Tab-style basket switcher to jump between baskets instantly
- List and grid view for browsing basket contents
- Quick actions to open, share, copy, or remove items fast
- Auto-hide when empty or idle — batch-drag items between apps

---

<h3 align="center">Clipboard Manager</h3>

<p align="center"><img src="docs/assets/images/feature-clipboard.png" width="500" alt="Clipboard Manager" /></p>

- Saves every text, image, file, link, and color you copy — persistent across restarts
- Full PDF and Office document viewer, plus inline video playback
- Custom tags with deep customization — filter, rename, color-code, and organize
- Flag, favorite, or star entries for quick access
- Push clipboard entries directly to the shelf or basket
- Source app filtering and full-text search across your entire history

---

<h3 align="center">Beautiful HUDs</h3>

<p align="center"><img src="docs/assets/images/feature-huds.png" width="500" alt="Beautiful HUDs" /></p>

- Replaces macOS system overlays with beautifully animated HUDs in your notch
- Volume, brightness, and keyboard backlight — including full external monitor support
- Now-playing with album art, progress scrubbing, and visualizer (Spotify & Apple Music)
- Full Apple Music controls: shuffle, repeat, love tracks, skip, and scrub
- AirPods connection with per-ear battery levels and charging state
- Notification banners, Do Not Disturb, power state, and mic/camera indicators

## <img src="docs/assets/icons/extensions.png" width="24"> Extensions

Modular extensions add even more power. **Install only what you need.**

| Icon | Extension | Description |
|:----:|-----------|-------------|
| <img src="docs/assets/icons/apple-music.png" width="24"> | [**Apple Music**](docs/extensions.html) | Full playback controls with shuffle, repeat, love tracks & lyrics |
| <img src="docs/assets/icons/spotify.png" width="24"> | [**Spotify**](docs/extensions.html) | Spotify playback with album art, visualizer & media controls |
| <img src="docs/assets/icons/notification-hud.png" width="24"> | [**Notify Me!**](docs/extensions.html) | Beautiful notification banners that appear in your notch |
| <img src="docs/assets/icons/window-snap.jpg" width="24"> | [**Window Snap**](docs/extensions.html) | Keyboard shortcuts for snapping windows to screen edges & displays |
| <img src="docs/assets/icons/high-alert.jpg" width="24"> | [**High Alert**](docs/extensions.html) | Keep your Mac awake with customizable timers & schedules |
| <img src="docs/assets/icons/terminotch.jpg" width="24"> | [**Termi-Notch**](docs/extensions.html) | Quick terminal access with hotkey — run commands instantly |
| <img src="docs/assets/icons/alfred.png" width="24"> | [**Alfred**](docs/extensions.html) | Deep Alfred integration — trigger workflows from your notch |
| <img src="docs/assets/icons/finder.png" width="24"> | [**Finder Services**](docs/extensions.html) | Right-click in Finder to add files to Shelf or Basket |
| <img src="docs/assets/icons/quickshare.jpg" width="24"> | [**Quickshare**](docs/extensions.html) | Upload files to the cloud, get instant shareable links |
| <img src="docs/assets/icons/targeted-video-size.jpg" width="24"> | [**Video Target Size**](docs/extensions.html) | Compress videos to exact file sizes using FFmpeg |
| <img src="docs/assets/icons/element-capture.jpg" width="24"> | [**Element Capture**](docs/extensions.html) | Screenshot & annotate with full editor: arrows, blur, text, shapes, configurable shortcuts |
| <img src="docs/assets/icons/voice-transcribe.jpg" width="24"> | [**Voice Transcribe**](docs/extensions.html) | Transcribe audio to text using on-device AI |
| <img src="docs/assets/icons/ai-bg.jpg" width="24"> | [**Background Removal**](docs/extensions.html) | Remove image backgrounds with AI — one click |
| <img src="docs/assets/icons/menubarmanager.png" width="24"> | [**Menu Bar Manager**](docs/extensions.html) | Hide & organize menu bar icons with hover reveal |
| <img src="docs/assets/icons/reminders.png" width="24"> | [**Reminders**](docs/extensions.html) | Capture tasks in natural language & sync with Apple Reminders |
| <img src="docs/assets/icons/snap-camera-v2.png" width="24"> | [**Notchface**](docs/extensions.html) | Floating camera button with full live preview in your notch |

## FAQ

<details>
<summary><b>Does it work on Macs without a notch?</b></summary>
<br>
Yes. PepBox works on all Macs (with or without a physical notch) using a "Dynamic Island" style bar.
</details>

<details>
<summary><b>How do I get updates?</b></summary>
<br>
PepBox checks the latest GitHub release of KPScriptz/PepBox once a day and can install it for you. Or use Homebrew: <code>brew upgrade --cask pepbox</code>
</details>

<details>
<summary><b>Does PepBox collect any data?</b></summary>
<br>
No. The analytics and extension-rating service from upstream Droppy has been removed.
</details>

## Building

Requirements: macOS 14 (Sonoma) or later to run; Xcode 26 or later to build (the app
icon uses the Icon Composer `.icon` format).

1. Open `PepBox.xcodeproj` in Xcode.
2. Under *Signing & Capabilities*, pick your team (the project ships with none set).
3. Build and run the `PepBox` scheme.
4. Optional: `./build_helper.sh` builds the `PepBoxUpdater` helper into `build/Release/PepBox.app`.

Swift packages (WhisperKit, SwiftTerm, SkyLightWindow) resolve on first build.
`reset_dev_permissions.sh` clears the app's privacy permissions during development.

## Releasing

`release_pepbox.sh` builds a universal binary, signs and notarizes it, packages a DMG,
updates the Homebrew cask and website version, tags the release and publishes it with
`gh release create`.

```bash
export PEPBOX_SIGNING_IDENTITY="Developer ID Application: <Your Company> (<TEAMID>)"
export PEPBOX_TEAM_ID="<TEAMID>"
export PEPBOX_TAP_REPO=~/src/homebrew-tap      # optional
xcrun notarytool store-credentials PepBox-Notarize   # once
./release_pepbox.sh 1.0.0 release_notes.txt
```

It needs an Apple Developer ID certificate, the `gh` CLI and `npx` (for `create-dmg`).

## Website

`docs/` is the PepBox website (plain HTML), ready for GitHub Pages at
`kpscriptz.github.io/PepBox`. Install counts and ratings on the extensions page are
off until `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set in `docs/extensions.html`.

## Changelog

<!-- CHANGELOG_START -->
## What's New in PepBox 1.0.0

- First release of PepBox, based on Droppy 11.0.0
- New name, icon and bundle identifier (com.pivotxp.PepBox)
- Extension icons and previews now ship inside the app
- No analytics
<!-- CHANGELOG_END -->

## License

PepBox is a modified version of Droppy and is released under the same
[GPL-3.0 License with Commons Clause](LICENSE): you can use, modify and share it, but you
can't sell it or a service whose value comes mainly from it. [NOTICE](NOTICE) lists what
was changed; `upstream/` keeps Droppy's original README, release notes and launch post.

"Droppy" and its logo are trademarks of Jordy Spruit ([TRADEMARK](TRADEMARK)). PepBox is
not affiliated with the Droppy project.

<details>
<summary><sub>Credits & Acknowledgements</sub></summary>
<sub>
<br>
<b>Droppy</b> by Jordy Spruit, the project PepBox is built on (<a href="https://github.com/iordv/Droppy">github</a>)<br>
<b>Alcove</b>, inspiration for the notch design (<a href="https://tryalcove.com/">tryalcove.com</a>)<br>
<b>Boringnotch</b>, pioneered notch creativity on macOS (<a href="https://github.com/TheBoredTeam/boring.notch">github</a>)
</sub>
</details>
