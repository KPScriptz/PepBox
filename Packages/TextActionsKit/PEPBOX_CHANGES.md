# Text Actions: PepBox's changes to DropClip

Text Actions is **DropClip** (MIT; based on OpenClip by Ganesh M, taken while OpenClip was
MIT licensed) with **OpenSelection** (Apache-2.0, Ganesh M), taken from
`gitlab.com/droppyformac1/droplets` at the commit in `Legal/SOURCE_COMMIT.txt`.
Licence texts and notices are in `Legal/` and ship in the app (`Assets/Legal`).

## Why it changed

DropClip runs as a Droppy "droplet" through **DroppyKit**, a proprietary SDK licensed only for
building droplets for Droppy. PepBox can't use it, so:

- The Droppy host layer that imports DroppyKit is removed and replaced by `Sources/DropClip/PepBox/`
  (`PepBoxHost.swift`, `TextActionsRuntime.swift`, the latter ported from `DropClipDroplet.swift`).
- `DropClipHost.isInsideDroppy` is always false, so DropClip takes its standalone (upstream
  OpenClip) paths: its own settings window and popup glass. Droppy-only branches that drew
  DroppyKit views were removed.
- `DropClipHost.isHosted` is true: app-level things stay PepBox's. No activation-policy (Dock icon)
  switching, no relaunching, no `tccutil` reset, and no login-item changes from Text Actions.
- Droppy settings pages, the Shortcuts-page entries, the Droppy intro onboarding step and the
  OpenClip/droplet settings migration are removed.
- User-facing text says "Text Actions" (not DropClip) and names PepBox where the permission
  switch is concerned; About shows credits and the bundled licences instead of Droppy's links.
- Settings live in the `com.pivotxp.PepBox.textactions` defaults domain.
- Resources load from the package bundle (`Bundle.module`).

**OpenSelection is unmodified.** No code from OpenClip after the MIT→AGPL relicense (`7919d76`)
is used: everything here comes from DropClip, whose own PROVENANCE.md records that check.

## Files

### Removed (Droppy host layer)
- `DropClip/Droppy/DropClipDroplet.swift`
- `DropClip/Droppy/DropClipDroppyIntroStep.swift`
- `DropClip/Droppy/DropClipMigration.swift`
- `DropClip/Droppy/DropClipOpenClipImport.swift`
- `DropClip/Droppy/DropClipOpenClipImportRow.swift`
- `DropClip/Droppy/DropClipPageToolbar.swift`
- `DropClip/Droppy/DropClipPopupSurface.swift`
- `DropClip/Droppy/DropClipSettingsNavigation.swift`
- `DropClip/Droppy/DropClipSettingsPages.swift`
- `DropClip/Droppy/DropClipShortcutEntries.swift`

### Added
- `DropClip/PepBox/PepBoxHost.swift`, `DropClip/PepBox/TextActionsRuntime.swift`
- `DropClip/Resources/Assets` (from `Assets/`, plus `Legal/`)

### Modified
- `DropClipCore/Droppy/DropClipHostEnvironment.swift`
- `DropClipCore/Extensions/ShellProcessRunner.swift`
- `DropClipCore/Extensions/Trust/ExtensionTrustGate.swift`
- `DropClip/AI/AIServiceManager.swift`
- `DropClip/Droppy/AppUpdateManager.swift`
- `DropClip/Droppy/DropClipActionsFormList.swift`
- `DropClip/Droppy/DropClipAssets.swift`
- `DropClip/Droppy/DropClipIcons.swift`
- `DropClip/Droppy/DropClipNativeSettings.swift`
- `DropClip/Droppy/KeyboardShortcuts.swift`
- `DropClip/Platform/DeepLinkRouter.swift`
- `DropClip/Platform/LaunchAtLoginManager.swift`
- `DropClip/Platform/PermissionManager.swift`
- `DropClip/Platform/Runtimes/DropClipModuleLoader.swift`
- `DropClip/UI/CoachMark/CoachMarkController.swift`
- `DropClip/UI/Design/LiquidGlass.swift`
- `DropClip/UI/Onboarding/OnboardingView.swift`
- `DropClip/UI/Onboarding/OnboardingWindowController.swift`
- `DropClip/UI/PermissionRecovery/PermissionRecoveryView.swift`
- `DropClip/UI/PermissionRecovery/PermissionRecoveryWindowController.swift`
- `DropClip/UI/Popup/PopupPreview.swift`
- `DropClip/UI/Popup/PopupThemeModel.swift`
- `DropClip/UI/Popup/PopupThemeSelector.swift`
- `DropClip/UI/Preferences/AIActionsSection.swift`
- `DropClip/UI/Preferences/AICustomActionBuilder.swift`
- `DropClip/UI/Preferences/AIPage.swift`
- `DropClip/UI/Preferences/AboutTabView.swift`
- `DropClip/UI/Preferences/ActionDuplicator.swift`
- `DropClip/UI/Preferences/ActionEditorPage.swift`
- `DropClip/UI/Preferences/ActionSettingsRow.swift`
- `DropClip/UI/Preferences/AddApplicationPage.swift`
- `DropClip/UI/Preferences/AppRulesTab.swift`
- `DropClip/UI/Preferences/CustomActionsPage.swift`
- `DropClip/UI/Preferences/CustomizePage.swift`
- `DropClip/UI/Preferences/DynamicActionConfigView.swift`
- `DropClip/UI/Preferences/ExtensionCardView.swift`
- `DropClip/UI/Preferences/ExtensionsStoreView.swift`
- `DropClip/UI/Preferences/GeneralTabView.swift`
- `DropClip/UI/Preferences/GroupEditorPage.swift`
- `DropClip/UI/Preferences/InstalledExtensionInfo.swift`
- `DropClip/UI/Preferences/NewCustomActionPage.swift`
- `DropClip/UI/Preferences/NewGroupPage.swift`
- `DropClip/UI/Preferences/PreferencesView.swift`
- `DropClip/UI/Preferences/SettingsNavigationStack.swift`
- `DropClip/UI/Preferences/SettingsRouter.swift`
- `DropClip/UI/Preferences/SettingsRowLabel.swift`
- `DropClip/UI/Preferences/SettingsSidebar.swift`
- `DropClip/UI/Preferences/SettingsWindowController.swift`
- `DropClip/UI/Preferences/ShortcutRecorderPopover.swift`
