#!/bin/bash
# PepBox Development Reset Script
# Run this ONCE to fix broken permissions on your dev machine

echo "🔧 PepBox Development Reset"
echo "============================"

# 1. Kill PepBox if running
echo "1. Killing PepBox..."
killall PepBox 2>/dev/null || echo "   (not running)"

# 2. Reset TCC database entries
echo "2. Resetting TCC database..."
tccutil reset Accessibility com.pivotxp.PepBox
tccutil reset ScreenCapture com.pivotxp.PepBox
tccutil reset ListenEvent com.pivotxp.PepBox

# 3. Clear PepBox's UserDefaults cache
echo "3. Clearing permission cache..."
defaults delete com.pivotxp.PepBox accessibilityGranted 2>/dev/null || true
defaults delete com.pivotxp.PepBox screenRecordingGranted 2>/dev/null || true
defaults delete com.pivotxp.PepBox inputMonitoringGranted 2>/dev/null || true
defaults delete com.pivotxp.PepBox permissionCacheVersion 2>/dev/null || true

# 4. Clean Xcode build
echo "4. Cleaning Xcode build..."
cd "$(dirname "$0")"
xcodebuild clean -scheme PepBox -quiet 2>/dev/null || true

echo ""
echo "✅ Reset complete!"
echo ""
echo "Now do this:"
echo "1. Open Xcode"
echo "2. Build and Run (Cmd+R)"
echo "3. Grant ALL permissions when prompted"
echo "4. Quit and relaunch PepBox"
echo ""
echo "Everything should work after this."
