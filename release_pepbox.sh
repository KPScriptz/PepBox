#!/bin/bash

# Configuration
MAIN_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Optional: local checkout of KPScriptz/homebrew-tap. Leave unset to skip the tap.
TAP_REPO="${PEPBOX_TAP_REPO:-}"
# Required: your Developer ID signing identity and team, e.g.
#   export PEPBOX_SIGNING_IDENTITY="Developer ID Application: PivotXP LLC (ABCDE12345)"
#   export PEPBOX_TEAM_ID="ABCDE12345"
SIGNING_IDENTITY="${PEPBOX_SIGNING_IDENTITY:-}"
TEAM_ID="${PEPBOX_TEAM_ID:-}"

# --- Colors & Styles ---
BOLD="\033[1m"
RESET="\033[0m"
BLUE="\033[1;34m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
MAGENTA="\033[1;35m"
DIM="\033[2m"

# --- Helpers ---
info() { echo -e "${BLUE}==>${RESET} ${BOLD}$1${RESET}"; }
success() { echo -e "${GREEN}✔ $1${RESET}"; }
warning() { echo -e "${YELLOW}⚠ $1${RESET}"; }
error() { echo -e "${RED}✖ Error: $1${RESET}"; exit 1; }
step() { echo -e "   ${DIM}→ $1${RESET}"; }

header() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
 ____            ____
|  _ \ ___ _ __ | __ )  _____  __
| |_) / _ \ '_ \|  _ \ / _ \ \/ /
|  __/  __/ |_) | |_) | (_) >  <
|_|   \___| .__/|____/ \___/_/\_\
          |_|
EOF
    echo -e "${RESET}"
    echo -e "   ${CYAN}Release Manager v2.0${RESET}\n"
}

# Strict error handling
set -e

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Usage:${RESET} ./release_pepbox.sh [VERSION] [NOTES_FILE]"
    exit 1
fi

VERSION="$1"
NOTES_FILE="${2:-}"
AUTO_APPROVE_FLAG="${3:-}"
DMG_NAME="PepBox-$VERSION.dmg"

header
info "Preparing Release: ${GREEN}v$VERSION${RESET}"

# Check Repos
[ -d "$MAIN_REPO" ] || error "Main repo not found at $MAIN_REPO"
if [ -n "$TAP_REPO" ]; then
    [ -d "$TAP_REPO" ] || error "Tap repo not found at $TAP_REPO"
fi
[ -n "$SIGNING_IDENTITY" ] || error "Set PEPBOX_SIGNING_IDENTITY to your Developer ID Application identity"
[ -n "$TEAM_ID" ] || error "Set PEPBOX_TEAM_ID to your Apple Developer team ID"
cd "$MAIN_REPO" || error "Cannot enter main repo at $MAIN_REPO"

# Validate version format early (X.Y.Z)
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    error "Version must follow semantic format X.Y.Z (received: $VERSION)"
fi

# Ensure git is clean
if [ -n "$(git status --porcelain)" ]; then
    error "Git working directory is not clean. Commit or stash first."
fi
if [ -n "$TAP_REPO" ] && [ -n "$(git -C "$TAP_REPO" status --porcelain)" ]; then
    error "Homebrew tap working directory is not clean. Commit or stash first."
fi

# Update Release Notes
if [ -n "$NOTES_FILE" ] && [ -f "$NOTES_FILE" ]; then
    info "Syncing Documentation"
    step "Reading $NOTES_FILE..."
    NOTES_CONTENT=$(cat "$NOTES_FILE")
    export NEW_NOTES="$NOTES_CONTENT"
    
    step "Updating README.md Changelog..."
    # Update README with perl to handle multiline
    perl -0777 -i -pe 's/(<!-- CHANGELOG_START -->)(.*?)(<!-- CHANGELOG_END -->)/$1\n$ENV{NEW_NOTES}\n$3/s' README.md
    
    step "Updating Website Version to $VERSION..."
    # Update PEPBOX_VERSION in docs/index.html and docs/extensions.html
    sed -i '' "s/const PEPBOX_VERSION = '[^']*';/const PEPBOX_VERSION = '$VERSION';/" docs/index.html
    sed -i '' "s/const PEPBOX_VERSION = '[^']*';/const PEPBOX_VERSION = '$VERSION';/" docs/extensions.html
    
    # Update centralized version.js
    sed -i '' "s/version: '[^']*'/version: '$VERSION'/" docs/assets/js/version.js
    sed -i '' "s/PepBox-[0-9]*\.[0-9]*\.[0-9]*\.dmg/PepBox-$VERSION.dmg/g" docs/assets/js/version.js
else
    warning "No valid notes file provided. Skipping doc updates."
fi

# Update Project Version
info "Bumping Version"
cd "$MAIN_REPO" || exit
sed -i '' "s/MARKETING_VERSION = .*/MARKETING_VERSION = $VERSION;/" PepBox.xcodeproj/project.pbxproj
step "Set MARKETING_VERSION = $VERSION"

# Build
info "Compiling Binary"
APP_BUILD_PATH="$MAIN_REPO/build"
rm -rf "$APP_BUILD_PATH"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PepBox -configuration Release -derivedDataPath "$APP_BUILD_PATH" -destination 'generic/platform=macOS' -skipPackagePluginValidation -skipMacroValidation ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$TEAM_ID" -quiet || error "Build failed"
step "Build Successful"

# Build and Bundle Helper
info "Building PepBoxUpdater Helper"
HELPER_SRC="$MAIN_REPO/PepBoxUpdater/main.swift"
if [ -f "$HELPER_SRC" ]; then
    # Build for ARM64
    swiftc -o "$APP_BUILD_PATH/PepBoxUpdater-arm64" \
        "$HELPER_SRC" \
        -framework AppKit \
        -framework SwiftUI \
        -O \
        -target arm64-apple-macos14.0 || error "Helper build (ARM64) failed"
    
    # Build for x86_64
    swiftc -o "$APP_BUILD_PATH/PepBoxUpdater-x86_64" \
        "$HELPER_SRC" \
        -framework AppKit \
        -framework SwiftUI \
        -O \
        -target x86_64-apple-macos14.0 || error "Helper build (x86_64) failed"
    
    # Create universal binary
    lipo -create -output "$APP_BUILD_PATH/PepBoxUpdater" \
        "$APP_BUILD_PATH/PepBoxUpdater-arm64" \
        "$APP_BUILD_PATH/PepBoxUpdater-x86_64"
    rm -f "$APP_BUILD_PATH/PepBoxUpdater-arm64" "$APP_BUILD_PATH/PepBoxUpdater-x86_64"
    
    # Copy helper to app bundle
    HELPERS_DIR="$APP_BUILD_PATH/Build/Products/Release/PepBox.app/Contents/Helpers"
    mkdir -p "$HELPERS_DIR"
    cp "$APP_BUILD_PATH/PepBoxUpdater" "$HELPERS_DIR/"
    step "Universal helper bundled at Contents/Helpers/PepBoxUpdater"
else
    warning "PepBoxUpdater source not found, skipping helper"
fi

# Packaging
info "Packaging DMG"
cd "$MAIN_REPO" || exit
rm -f PepBox*.dmg

# Build PepBoxInstaller
info "Building PepBoxInstaller"
INSTALLER_SRC="$MAIN_REPO/PepBoxInstaller/main.swift"
INSTALLER_APP="$APP_BUILD_PATH/PepBoxInstaller.app"
if [ -f "$INSTALLER_SRC" ]; then
    # Build for ARM64
    swiftc -o "$APP_BUILD_PATH/PepBoxInstaller-arm64" \
        "$INSTALLER_SRC" \
        -framework AppKit \
        -framework SwiftUI \
        -O \
        -target arm64-apple-macos14.0 || error "Installer build (ARM64) failed"
    
    # Build for x86_64
    swiftc -o "$APP_BUILD_PATH/PepBoxInstaller-x86_64" \
        "$INSTALLER_SRC" \
        -framework AppKit \
        -framework SwiftUI \
        -O \
        -target x86_64-apple-macos14.0 || error "Installer build (x86_64) failed"
    
    # Create universal binary
    lipo -create -output "$APP_BUILD_PATH/PepBoxInstaller" \
        "$APP_BUILD_PATH/PepBoxInstaller-arm64" \
        "$APP_BUILD_PATH/PepBoxInstaller-x86_64"
    rm -f "$APP_BUILD_PATH/PepBoxInstaller-arm64" "$APP_BUILD_PATH/PepBoxInstaller-x86_64"
    
    # Create proper .app bundle for installer
    mkdir -p "$INSTALLER_APP/Contents/MacOS"
    mkdir -p "$INSTALLER_APP/Contents/Resources"
    cp "$APP_BUILD_PATH/PepBoxInstaller" "$INSTALLER_APP/Contents/MacOS/"
    
    # Copy PepBox's icon to installer
    cp "$APP_BUILD_PATH/Build/Products/Release/PepBox.app/Contents/Resources/AppIcon.icns" "$INSTALLER_APP/Contents/Resources/" 2>/dev/null || true
    
    # Create Info.plist
    cat > "$INSTALLER_APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PepBoxInstaller</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.pivotxp.PepBoxInstaller</string>
    <key>CFBundleName</key>
    <string>Install PepBox</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
PLIST
    step "PepBoxInstaller.app built"
else
    warning "PepBoxInstaller source not found"
fi

# Code Signing
info "Signing Application"
APP_PATH="$APP_BUILD_PATH/Build/Products/Release/PepBox.app"
SOURCE_INFO_PLIST="$MAIN_REPO/PepBox/Info.plist"
APP_INFO_PLIST="$APP_PATH/Contents/Info.plist"
RESOURCE_INFO_PLIST="$APP_PATH/Contents/Resources/Info.plist"

# Ensure release bundle includes all privacy and license metadata from source Info.plist.
info "Syncing App Metadata"
METADATA_KEYS=(
    NSAppleEventsUsageDescription
    NSBluetoothAlwaysUsageDescription
    NSCameraUsageDescription
    NSMicrophoneUsageDescription
    NSRemindersUsageDescription
    NSRemindersFullAccessUsageDescription
    NSCalendarsUsageDescription
    NSCalendarsFullAccessUsageDescription
)

[ -f "$SOURCE_INFO_PLIST" ] || error "Source Info.plist missing at $SOURCE_INFO_PLIST"
[ -f "$APP_INFO_PLIST" ] || error "Built app Info.plist missing at $APP_INFO_PLIST"

read_plist_value() {
    local plist_path="$1"
    local key="$2"
    /usr/libexec/PlistBuddy -c "Print :$key" "$plist_path" 2>/dev/null || true
}

sync_metadata_keys() {
    local target_plist="$1"
    local key source_value
    [ -f "$target_plist" ] || return 0

    for key in "${METADATA_KEYS[@]}"; do
        source_value="$(read_plist_value "$SOURCE_INFO_PLIST" "$key")"
        if [ -n "$source_value" ]; then
            plutil -replace "$key" -string "$source_value" "$target_plist"
        fi
    done
}

validate_required_app_keys() {
    local target_plist="$1"
    local key

    for key in NSRemindersUsageDescription NSCalendarsUsageDescription; do
        /usr/libexec/PlistBuddy -c "Print :$key" "$target_plist" >/dev/null 2>&1 || error "Missing required key $key in $target_plist"
    done
}

validate_dmg_bundle_metadata() {
    local dmg_path="$1"
    local mount_dir dmg_app_info

    mount_dir="$(mktemp -d /tmp/pepbox-dmg-XXXX)"
    if ! hdiutil attach -nobrowse -readonly -mountpoint "$mount_dir" "$dmg_path" >/dev/null; then
        rmdir "$mount_dir" 2>/dev/null || true
        error "Failed to mount $dmg_path for metadata verification"
    fi

    dmg_app_info="$mount_dir/PepBox.app/Contents/Info.plist"
    if [ ! -f "$dmg_app_info" ]; then
        hdiutil detach "$mount_dir" >/dev/null 2>&1 || true
        rmdir "$mount_dir" 2>/dev/null || true
        error "PepBox.app Info.plist missing inside $dmg_path"
    fi

    validate_required_app_keys "$dmg_app_info"

    hdiutil detach "$mount_dir" >/dev/null 2>&1 || error "Failed to detach DMG mount after verification"
    rmdir "$mount_dir" 2>/dev/null || true
}

sync_metadata_keys "$APP_INFO_PLIST"
sync_metadata_keys "$RESOURCE_INFO_PLIST"
validate_required_app_keys "$APP_INFO_PLIST"
step "App metadata synced and validated"

# Sign all nested components first (helpers, frameworks)
find "$APP_PATH/Contents" -name "*.dylib" -o -name "*.framework" | while read -r item; do
    codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$item" 2>/dev/null || true
done

# Sign helper if exists
if [ -f "$APP_PATH/Contents/Helpers/PepBoxUpdater" ]; then
    codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$APP_PATH/Contents/Helpers/PepBoxUpdater"
    step "Signed PepBoxUpdater helper"
fi

# Sign the main app
codesign --force --options runtime --sign "$SIGNING_IDENTITY" --entitlements "$MAIN_REPO/PepBox/PepBox.entitlements" "$APP_PATH" || error "Code signing failed"
step "Signed PepBox.app with Developer ID"

# Verify signature
codesign --verify --deep --strict "$APP_PATH" || error "Signature verification failed"
step "Signature verified"

# Packaging DMG (classic drag-to-Applications)
info "Packaging DMG"
DMG_NAME="PepBox-$VERSION.dmg"
rm -f PepBox*.zip PepBox*.dmg rw.*.dmg

# Create DMG using Sindre's create-dmg (clean, respects user's appearance)
npx create-dmg "$APP_PATH" . --overwrite 2>/dev/null || error "DMG creation failed"

# Rename to our versioned name
mv "PepBox $VERSION.dmg" "$DMG_NAME" 2>/dev/null || mv PepBox*.dmg "$DMG_NAME" 2>/dev/null

# Validate final packaged app metadata before signing/publishing.
validate_dmg_bundle_metadata "$DMG_NAME"
step "DMG metadata validated"

# Sign the DMG too
codesign --force --sign "$SIGNING_IDENTITY" "$DMG_NAME" || error "DMG signing failed"
step "Signed DMG"

# Notarization
info "Notarizing with Apple"
step "Submitting to Apple notary service..."

# Submit for notarization (uses stored credentials "PepBox-Notarize")
if ! xcrun notarytool submit "$DMG_NAME" --keychain-profile "PepBox-Notarize" --wait; then
    error "Notarization failed. Configure credentials with 'xcrun notarytool store-credentials PepBox-Notarize'."
fi

# Staple the notarization ticket to the DMG
if ! xcrun stapler staple "$DMG_NAME" 2>/dev/null; then
    error "Stapling failed. Refusing to publish unstapled DMG."
fi
step "Notarization ticket stapled"

success "$DMG_NAME created and notarized"

# Checksum
info "Generating Integrity Checksum"
HASH=$(shasum -a 256 "$DMG_NAME" | awk '{print $1}')
step "SHA256: ${DIM}$HASH${RESET}"

# Generate Cask
CASK_CONTENT="cask \"pepbox\" do
  version \"$VERSION\"
  sha256 \"$HASH\"

  url \"https://github.com/KPScriptz/PepBox/releases/download/v$VERSION/$DMG_NAME\"
  name \"PepBox\"
  desc \"Drag and drop file shelf for macOS\"
  homepage \"https://github.com/KPScriptz/PepBox\"

  auto_updates true

  app \"PepBox.app\"

  postflight do
    system_command \"/usr/bin/xattr\",
      args: [\"-d\", \"com.apple.quarantine\", \"#{appdir}/PepBox.app\"],
      must_succeed: false,
      sudo: false
  end

  caveats <<~EOS
    Thank you for installing PepBox! 
    The ultimate drag-and-drop file shelf for macOS.
  EOS

  zap trash: [
    \"~/Library/Application Support/PepBox\",
    \"~/Library/Preferences/com.pivotxp.PepBox.plist\",
  ]
end"

# Update Casks
info "Updating Homebrew Casks"
echo "$CASK_CONTENT" > "$MAIN_REPO/Casks/pepbox.rb"
if [ -n "$TAP_REPO" ]; then
    echo "$CASK_CONTENT" > "$TAP_REPO/Casks/pepbox.rb"
fi

# Verify both casks have correct version URL
if ! grep -q "v$VERSION/$DMG_NAME" "$MAIN_REPO/Casks/pepbox.rb"; then
    error "Main repo cask verification failed"
fi
if [ -n "$TAP_REPO" ] && ! grep -q "v$VERSION/$DMG_NAME" "$TAP_REPO/Casks/pepbox.rb"; then
    error "Tap repo cask verification failed"
fi
step "Cask files written and verified for v$VERSION"

# Commit Changes
info "Finalizing Git Repositories"

# Confirm
if [ "$AUTO_APPROVE_FLAG" == "-y" ] || [ "$AUTO_APPROVE_FLAG" == "--yes" ]; then
    REPLY="y"
else
    echo -e "\n${BOLD}Review Pending Changes:${RESET}"
    echo -e "   • Version: ${GREEN}$VERSION${RESET}"
    echo -e "   • Binary:  ${CYAN}$DMG_NAME${RESET}"
    echo -e "   • Hash:    ${DIM}${HASH:0:8}...${RESET}"
    read -p "❓ Publish release now? [y/N] " -n 1 -r
    echo
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Main Repo Commit
    cd "$MAIN_REPO"
    step "Pushing Main Repo..."
    git pull --ff-only origin main --quiet
    git rm --ignore-unmatch PepBox*.dmg PepBox*.zip --quiet 2>/dev/null || true
    # The DMG is attached to the GitHub release, not committed (*.dmg is gitignored).
    git add .
    git commit -m "Release v$VERSION" --quiet
    git tag "v$VERSION"
    git push origin main --quiet
    git push origin "v$VERSION" --quiet
    
    # Tap Repo Commit
    if [ -n "$TAP_REPO" ]; then
        cd "$TAP_REPO"
        step "Pushing Tap Repo..."
        git fetch origin --quiet
        git checkout main --quiet
        git pull --ff-only origin main --quiet
        echo "$CASK_CONTENT" > "Casks/pepbox.rb"

        # Verify cask contains correct version in URL (guard against variable corruption)
        if ! grep -q "v$VERSION/$DMG_NAME" "Casks/pepbox.rb"; then
            error "Cask verification failed: URL does not contain v$VERSION/$DMG_NAME"
        fi
        step "Cask verified: URL points to v$VERSION"

        git add .
        git commit -m "Update PepBox to v$VERSION" --quiet || warning "No changes to commit in tap repo"
        git push origin HEAD:main --quiet
    fi

    # GitHub Release
    info "Creating GitHub Release"
    cd "$MAIN_REPO"
    
    # Append installation instructions to notes
    TEMP_NOTES=$(mktemp)
    if [ -n "$NOTES_FILE" ] && [ -f "$NOTES_FILE" ]; then
        cat "$NOTES_FILE" > "$TEMP_NOTES"
    else
        cat > "$TEMP_NOTES" << FALLBACK_NOTES
## What's New
- Release v$VERSION
FALLBACK_NOTES
    fi
    cat >> "$TEMP_NOTES" << INSTALL_FOOTER

---

## Installation

<img src="https://raw.githubusercontent.com/KPScriptz/PepBox/main/docs/assets/macos-disk-icon.png" height="24"> **Recommended: Direct Download** (signed & notarized)

Download \`PepBox-$VERSION.dmg\` below, open it, and drag PepBox to Applications. That's it!

> ✅ **Signed & Notarized by Apple** — No quarantine warnings, no terminal commands needed.

<img src="https://brew.sh/assets/img/homebrew.svg" height="24"> **Alternative: Install via Homebrew**
\`\`\`bash
brew install --cask KPScriptz/tap/pepbox
\`\`\`
INSTALL_FOOTER
    
    gh release create "v$VERSION" "$DMG_NAME" --title "v$VERSION" --notes-file "$TEMP_NOTES"
    rm -f "$TEMP_NOTES"
    
    echo -e "\n${GREEN}✨ RELEASE COMPLETE! ✨${RESET}"
    echo -e "Users can now update with: ${CYAN}brew upgrade --cask pepbox${RESET}\n"
else
    warning "Release cancelled. Changes pending locally."
fi
