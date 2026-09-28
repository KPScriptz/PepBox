#!/bin/bash
# Drives a built PepBox.app like a user would and records what happens.
# Usage: scripts/uitest/run.sh path/to/PepBox.app output-dir
# Every step takes a screenshot; the log, window list and file checks go
# to output-dir/report.txt.

APP="$1"
OUT="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"
REPORT="$OUT/report.txt"
: > "$REPORT"

swiftc -O -o "$OUT/driver" "$HERE/driver.swift" -framework Cocoa || exit 1
D="$OUT/driver"

say() { echo "== $*" | tee -a "$REPORT"; }
# Run a command with a time limit so a hidden permission prompt can't hang the job.
t() { local secs=$1; shift; perl -e 'alarm shift; exec @ARGV' "$secs" "$@"; local rc=$?; [ $rc -ne 0 ] && say "TIMEOUT/FAIL ($rc): $*"; return $rc; }
step=0
shot() {
    step=$((step + 1))
    local name
    name=$(printf "%02d-%s" "$step" "$1")
    t 15 screencapture -x "$OUT/$name.png"
    sips -s format jpeg -s formatOptions 60 "$OUT/$name.png" --out "$OUT/$name.jpg" >/dev/null 2>&1 && rm "$OUT/$name.png"
    say "screenshot $name"
}
pepbox_windows() { t 10 "$D" windows PepBox | tee -a "$REPORT"; }

read -r W H < <("$D" screen)
CX=$((W / 2))
say "screen ${W}x${H}"

# Test files in a folder shown in a Finder window at a fixed place
TEST="$HOME/Desktop/pepbox-ui-test"
DROP="$HOME/Desktop/pepbox-drop-target"
rm -rf "$TEST" "$DROP"; mkdir -p "$TEST" "$DROP"
echo "hello from the PepBox UI test" > "$TEST/note.txt"
cp "$APP/Contents/Resources/"*alfred*.png "$TEST/picture.png" 2>/dev/null || sips -s format png "$APP/Contents/Resources/"*.jpg --out "$TEST/picture.png" >/dev/null 2>&1

# Launch, capturing stdout/stderr (the app logs with print)
pkill -x PepBox 2>/dev/null; sleep 1
"$APP/Contents/MacOS/PepBox" > "$OUT/app-stdout.log" 2>&1 &
APP_PID=$!
sleep 12
say "PepBox pid $APP_PID running: $(kill -0 $APP_PID 2>/dev/null && echo yes || echo NO)"
shot launched
pepbox_windows

say "hover the notch"
"$D" move $CX 3; sleep 0.3; "$D" move $((CX + 5)) 5; sleep 1.5
shot hover-notch
pepbox_windows
"$D" move $CX 400; sleep 1

# Finder window with the test files, icons at known spots
t 25 osascript <<EOF >> "$REPORT" 2>&1
tell application "Finder"
    activate
    close every window
    set w to make new Finder window to (POSIX file "$TEST" as alias)
    set current view of w to icon view
    set bounds of w to {80, 200, 680, 600}
    set arrangement of icon view options of w to not arranged
    set position of item "note.txt" of w to {100, 100}
    set position of item "picture.png" of w to {250, 100}
    set w2 to make new Finder window to (POSIX file "$DROP" as alias)
    set current view of w2 to icon view
    set bounds of w2 to {760, 200, 1260, 600}
end tell
EOF
sleep 2
shot finder-ready
t 10 "$D" windows Finder | tee -a "$REPORT"

# Finder window content starts below its toolbar; find the icon by trying the
# expected spot. Window top 200 + toolbar ~ 52..90, icon centre at +100.
NOTE_X=$((80 + 100)); NOTE_Y=$((200 + 70 + 100))

say "drag note.txt from Finder onto the notch"
t 20 "$D" drag $NOTE_X $NOTE_Y $CX 6 &
sleep 1.4; shot mid-drag-to-notch
wait
sleep 1.5
shot after-drop-on-notch
"$D" move $CX 3; sleep 0.3; "$D" move $((CX + 4)) 5; sleep 1.5
shot shelf-after-drop
pepbox_windows

say "add picture.png through the pepbox:// URL scheme"
t 10 open "pepbox://add?target=shelf&path=$TEST/picture.png"; sleep 2
"$D" move $CX 3; sleep 0.3; "$D" move $((CX + 4)) 5; sleep 1.5
shot shelf-after-url-add
pepbox_windows > "$OUT/shelf-windows.txt"; cat "$OUT/shelf-windows.txt" >> "$REPORT"

# Drag the first shelf item out into the drop-target Finder window. The shelf
# is the widest PepBox window near the top; items start at its left edge.
read -r SX SY SW SH < <(awk -F'\t' '{print $3}' "$OUT/shelf-windows.txt" \
    | sed -E 's/x=(-?[0-9]+) y=(-?[0-9]+) w=([0-9]+) h=([0-9]+)/\1 \2 \3 \4/' \
    | awk '$2 < 60 && $4 > 60 {print $3*$4, $0}' | sort -rn | head -1 | cut -d' ' -f2-)
say "shelf window guess: x=$SX y=$SY w=$SW h=$SH"
if [ -n "$SW" ]; then
    ITEM_X=$((SX + SW / 2 - 60)); ITEM_Y=$((SY + SH / 2 + 10))
    say "drag shelf item at $ITEM_X,$ITEM_Y out to the drop-target window"
    t 20 "$D" drag $ITEM_X $ITEM_Y 1010 420 &
    sleep 1.4; shot mid-drag-out
    wait; sleep 2
    shot after-drag-out
fi
say "drop-target folder now contains: $(ls "$DROP" | tr '\n' ' ')"

say "floating basket: shake while dragging picture.png"
PIC_X=$((80 + 250)); PIC_Y=$NOTE_Y
t 20 "$D" jiggle $PIC_X $PIC_Y 500 700
sleep 1; shot basket-jiggle
"$D" up 500 700; sleep 1.5
shot basket-after-release
pepbox_windows

say "clipboard history: copy text, press cmd+shift+space"
echo "PepBox clipboard test $(date +%s)" | pbcopy; sleep 1
"$D" move $CX 500
t 10 "$D" key 49 cmd shift; sleep 2
shot clipboard-shortcut
pepbox_windows
"$D" key 53; sleep 1

say "menu bar icon"
t 10 "$D" windows | grep -i 'pepbox\|Control Center' | head -5 | tee -a "$REPORT"

say "PepBox still running at end: $(kill -0 $APP_PID 2>/dev/null && echo yes || echo NO)"
shot final
kill $APP_PID 2>/dev/null
grep -iE 'error|fail|warn|denied|not granted|permission' "$OUT/app-stdout.log" | sort | uniq -c | sort -rn | head -40 > "$OUT/app-problems.txt"
exit 0
