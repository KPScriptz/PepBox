#!/bin/bash
# Compiles PepBox's dependency-free logic files with the tests and runs them.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${TMPDIR:-/tmp}/pepbox-logic-tests"
swiftc -O -o "$OUT" \
    "$ROOT/PepBox/Extensions/Utilities/QuickSearchMath.swift" \
    "$ROOT/PepBox/Extensions/Utilities/ScrollEasing.swift" \
    "$ROOT/PepBox/Extensions/NotchWidgets/AudioSampleCopier.swift" \
    "$ROOT/PepBox/Extensions/NotchWidgets/Pomodoro.swift" \
    "$ROOT/PepBox/SavedShortcut.swift" \
    "$ROOT/PepBox/Extensions/NotchWidgets/EmojiPicker.swift" \
    "$ROOT/PepBox/Extensions/NotchWidgets/Obsidian.swift" \
    "$ROOT/PepBox/Lyrics/LyricsParser.swift" \
    "$ROOT/PepBox/ImageMetadataStripper.swift" \
    "$ROOT/PepBox/QRCodePanel.swift" \
    "$ROOT/PepBox/Extensions/Utilities/QuickCommands.swift" \
    "$ROOT/scripts/logic-tests/main.swift"
"$OUT"
