#!/bin/bash
# PepBox long-run usage simulation: ~6 months of heavy, adversarial use replayed against the
# app's real logic code (compiled standalone, like scripts/logic-tests). Deterministic (seeded),
# dates are injected (nothing sleeps). Each scenario runs in its own process; a crash or hang is
# reported with the exact input and the scenario resumes after it. Exits non-zero on any failure.
#
#   bash scripts/simulation/run.sh            # every scenario
#   bash scripts/simulation/run.sh http dates # just these
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SIM="$ROOT/scripts/simulation"
WORK="${TMPDIR:-/tmp}/pepbox-simulation"
BIN="$WORK/pepbox-simulation"
mkdir -p "$WORK"

# Parts of app files that need the UI are cut out with sed, as in scripts/logic-tests.
SNIPPET_ENGINE="$WORK/snippet-engine.swift"
{ echo "import Foundation"; sed -n '/^struct Snippet: Codable/,/^\/\/ MARK: - Controller/p' "$ROOT/PepBox/Extensions/Utilities/Snippets.swift"; } > "$SNIPPET_ENGINE"
AGENTS_PARSER="$WORK/agents-parser.swift"
{ echo "import Foundation"; sed -n '/^\/\/ MARK: - Parsing/,/^\/\/ MARK: - Monitor/p' "$ROOT/PepBox/Extensions/NotchWidgets/Agents.swift"; } > "$AGENTS_PARSER"
AGENT_FILES="$WORK/agent-log-files.swift"
{ echo "import Foundation"; echo "enum AgentLogFiles {"
  sed -n '/^    static func firstLine(of url: URL)/,/^    \/\/ MARK: Presentation/p' "$ROOT/PepBox/Extensions/NotchWidgets/Agents.swift" | sed '$d'
  echo "}"; } > "$AGENT_FILES"

SOURCES=(
    "$ROOT/PepBox/Extensions/Utilities/QuickSearchMath.swift"
    "$ROOT/PepBox/Extensions/Utilities/QuickTools.swift"
    "$ROOT/PepBox/Extensions/Utilities/QuickCommands.swift"
    "$ROOT/PepBox/Extensions/Utilities/LocalSend.swift"
    "$ROOT/PepBox/Extensions/Utilities/LocalSendHTTP.swift"
    "$ROOT/PepBox/Extensions/NotchWidgets/Pomodoro.swift"
    "$ROOT/PepBox/FileTools.swift"
    "$ROOT/PepBox/ClipboardStack.swift"
    "$ROOT/PepBox/ImageMetadataStripper.swift"
    "$SNIPPET_ENGINE" "$AGENTS_PARSER" "$AGENT_FILES"
    "$SIM/Support.swift" "$SIM/SimClipboard.swift" "$SIM/SimQuickSearch.swift" "$SIM/SimDates.swift"
    "$SIM/SimFocusSnippets.swift" "$SIM/SimNetwork.swift" "$SIM/SimFiles.swift" "$SIM/SimAgentsText.swift"
    "$SIM/main.swift"
)

# Rebuild only when a source changed (the optimized build is most of the run time).
HASH="$(cat "${SOURCES[@]}" | shasum | cut -d' ' -f1)"
if [[ ! -x "$BIN" || "$(cat "$WORK/build.hash" 2>/dev/null)" != "$HASH" ]]; then
    echo "Compiling the simulation (swiftc -O, whole module)…"
    BUILD_START=$SECONDS
    swiftc -O -wmo -num-threads 8 -suppress-warnings -o "$BIN" "${SOURCES[@]}" || { echo "FAIL build"; exit 1; }
    echo "$HASH" > "$WORK/build.hash"
    echo "Built in $((SECONDS - BUILD_START))s"
fi

ALL=(clipboard quicksearch dates focus snippets http localsend files agents transforms)
if [[ $# -gt 0 ]]; then REQUESTED=("$@"); else REQUESTED=("${ALL[@]}" perf); fi

# Runs one scenario (or one shard of it), restarting after each crash/hang at the next case.
run_scenario() {
    local name=$1 shard=${2:-0/1} tag="$1.${2//\//of}" start=0 attempts=0 code info idx desc kind
    local out="$WORK/$tag.out" crumb="$WORK/$tag.crumb"
    : > "$out"
    while :; do
        PEPSIM_SHARD="$shard" PEPSIM_CRUMB="$crumb" TZ=America/Chicago "$BIN" "$name" "$start" >> "$out" 2> "$WORK/$tag.err"
        code=$?
        [[ $code -le 1 ]] && break
        info="$(head -c 16384 "$crumb" 2>/dev/null | tr '\0' '\n' | head -1)"
        idx="$(printf '%s' "$info" | cut -f2)"
        desc="$(printf '%s' "$info" | cut -f3-)"
        kind=CRASH; [[ $code -eq 124 ]] && kind=HANG
        echo "$kind [$name] exit $code$([[ $code -gt 128 ]] && echo " (signal $((code - 128)))") at case ${idx:-?}: ${desc:0:400}" >> "$out"
        attempts=$((attempts + 1))
        # Sequential (stateful) scenarios can't skip a case; stop if the same case fails again.
        if [[ -z "$idx" || ! "$idx" =~ ^[0-9]+$ || $attempts -ge 15 || $((idx + 1)) -eq $start ]]; then
            echo "$kind [$name] not resumable past case ${idx:-?}; stopping after $attempts restart(s)" >> "$out"; break
        fi
        start=$((idx + 1))
    done
}

# Slow, independent-case scenarios are split across processes.
shards_for() { case $1 in dates) echo 4 ;; quicksearch) echo 2 ;; *) echo 1 ;; esac; }

START=$SECONDS
rm -f "$WORK"/*.out
for name in "${REQUESTED[@]}"; do
    [[ $name == perf ]] && continue
    n=$(shards_for "$name")
    for ((k = 0; k < n; k++)); do run_scenario "$name" "$k/$n" & done
done
wait
# Timings are measured alone, after everything else has finished.
for name in "${REQUESTED[@]}"; do [[ $name == perf ]] && run_scenario perf; done

STATUS=0
SUMMARY_LINES=()
for name in "${REQUESTED[@]}"; do
    outs=("$WORK/$name".*.out)
    cat "${outs[@]}" | grep -v '^RESULT|' | sed 's/^/  /'
    read -r CHECKS FAILED MS RESULTS <<< "$(cat "${outs[@]}" | awk -F'|' '/^RESULT\|/ {c += $3; f += $4; if ($5 > t) t = $5; r++} END {print c + 0, f + 0, t + 0, r + 0}')"
    CRASHES=$(cat "${outs[@]}" | grep -c '^CRASH \[' || true); HANGS=$(cat "${outs[@]}" | grep -c '^HANG \[' || true)
    SUMMARY_LINES+=("$(printf '%-12s %8d %8d %7d %6d %8.1fs' "$name" "$CHECKS" "$FAILED" "$CRASHES" "$HANGS" "$(echo "$MS / 1000" | bc -l)")")
    if [[ $RESULTS -lt ${#outs[@]} || $FAILED -gt 0 || $CRASHES -gt 0 || $HANGS -gt 0 ]]; then STATUS=1; fi
done
printf '\n%-12s %8s %8s %7s %6s %9s\n' SCENARIO CHECKS FAILED CRASH HANG TIME
printf '%s\n' "${SUMMARY_LINES[@]}"
echo "Simulation wall time $((SECONDS - START))s"
if [[ $STATUS -eq 0 ]]; then echo "OK all scenarios passed"; else echo "FAILED (see FAIL/CRASH/HANG lines above)"; fi
exit $STATUS
