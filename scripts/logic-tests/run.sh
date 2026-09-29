#!/bin/bash
# Compiles PepBox's dependency-free logic files with the tests and runs them.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${TMPDIR:-/tmp}/pepbox-logic-tests"
swiftc -O -o "$OUT" \
    "$ROOT/PepBox/Extensions/Utilities/QuickSearchMath.swift" \
    "$ROOT/PepBox/Extensions/Utilities/ScrollEasing.swift" \
    "$ROOT/PepBox/Extensions/NotchWidgets/AudioSampleCopier.swift" \
    "$ROOT/scripts/logic-tests/main.swift"
"$OUT"
