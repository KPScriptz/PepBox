cask "pepbox" do
  version "1.0.0"
  sha256 :no_check # release_pepbox.sh writes the real checksum on each release

  url "https://github.com/KPScriptz/PepBox/releases/download/v#{version}/PepBox-#{version}.dmg"
  name "PepBox"
  desc "Drag and drop file shelf for macOS"
  homepage "https://github.com/KPScriptz/PepBox"

  auto_updates true

  app "PepBox.app"

  postflight do
    system_command "/usr/bin/xattr",
      args: ["-d", "com.apple.quarantine", "#{appdir}/PepBox.app"],
      must_succeed: false,
      sudo: false
  end

  caveats <<~EOS
    Thank you for installing PepBox!
    The ultimate drag-and-drop file shelf for macOS.
  EOS

  zap trash: [
    "~/Library/Application Support/PepBox",
    "~/Library/Preferences/com.pivotxp.PepBox.plist",
  ]
end
