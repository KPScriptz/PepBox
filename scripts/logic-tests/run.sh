#!/bin/bash
# Compiles PepBox's dependency-free logic files with the tests and runs them.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${TMPDIR:-/tmp}/pepbox-logic-tests"
# Snippets.swift's engine is pure; the rest needs the app.
SNIPPET_ENGINE="${TMPDIR:-/tmp}/pepbox-snippet-engine.swift"
{ echo "import Foundation"; sed -n '/^struct Snippet: Codable/,/^\/\/ MARK: - Controller/p' "$ROOT/PepBox/Extensions/Utilities/Snippets.swift"; } > "$SNIPPET_ENGINE"
# Agents.swift depends on app UI types, so only its parser section is compiled.
AGENTS_PARSER="${TMPDIR:-/tmp}/pepbox-agents-parser.swift"
{ echo "import Foundation"; sed -n '/^\/\/ MARK: - Parsing/,/^\/\/ MARK: - Monitor/p' "$ROOT/PepBox/Extensions/NotchWidgets/Agents.swift"; } > "$AGENTS_PARSER"
# The app bundles copies of NOTICE and LICENSE for its licenses screen; keep them identical.
cmp -s "$ROOT/NOTICE" "$ROOT/PepBox/Legal/NOTICE.txt" || { echo "FAIL PepBox/Legal/NOTICE.txt differs from NOTICE"; exit 1; }
cmp -s "$ROOT/LICENSE" "$ROOT/PepBox/Legal/LICENSE.txt" || { echo "FAIL PepBox/Legal/LICENSE.txt differs from LICENSE"; exit 1; }
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
    "$AGENTS_PARSER" \
    "$SNIPPET_ENGINE" \
    "$ROOT/PepBox/Extensions/Utilities/LocalSend.swift" \
    "$ROOT/PepBox/Extensions/Utilities/LocalSendHTTP.swift" \
    "$ROOT/PepBox/Extensions/Utilities/QuickTools.swift" \
    "$ROOT/PepBox/FileTools.swift" \
    "$ROOT/PepBox/ClipboardStack.swift" \
    "$ROOT/PepBox/Extensions/NotchWidgets/MoreWidgetsLogic.swift" \
    "$ROOT/PepBox/Extensions/Utilities/ConvertRingLogic.swift" \
    "$ROOT/scripts/logic-tests/main.swift"
"$OUT"
