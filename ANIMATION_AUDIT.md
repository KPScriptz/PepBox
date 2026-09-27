# Animation Audit

Generated: 2026-02-08 18:16:37 CET

## Summary

- Swift files scanned: 207
- Files with animation usage: 80
- Files with raw (non-SSOT) animation usage: 55
- Total animation call sites: 832
- SSOT call sites (PepBoxAnimation.*): 528
- Raw call sites: 304
- Hardcoded primitive curve/timing sites: 119

## Raw Primitive Breakdown

| Primitive | Count |
|---|---:|
| `.easeInOut(` | 28 |
| `.linear(` | 22 |
| `CAMediaTimingFunction(` | 21 |
| `.spring(` | 16 |
| `.easeOut(` | 16 |
| `.smooth(` | 11 |
| `.interactiveSpring(` | 5 |

## File Coverage

| File | Sites | Raw | Status |
|---|---:|---:|---|
| `PepBox/AdaptiveColors.swift` | 0 | 0 | clean |
| `PepBox/AirPodsHUDView.swift` | 6 | 6 | raw-only |
| `PepBox/AirPodsManager.swift` | 0 | 0 | clean |
| `PepBox/AnalyticsService.swift` | 0 | 0 | clean |
| `PepBox/AnyButtonStyle.swift` | 0 | 0 | clean |
| `PepBox/AppKitMotion.swift` | 2 | 2 | raw-only |
| `PepBox/AppleScriptRuntime.swift` | 0 | 0 | clean |
| `PepBox/AudioSpectrumView.swift` | 1 | 1 | raw-only |
| `PepBox/AutoUpdater.swift` | 0 | 0 | clean |
| `PepBox/AutofadeManager.swift` | 0 | 0 | clean |
| `PepBox/BasketDragContainer.swift` | 0 | 0 | clean |
| `PepBox/BasketItemView.swift` | 31 | 11 | mixed |
| `PepBox/BasketQuickActionsBar.swift` | 10 | 0 | ssot-only |
| `PepBox/BasketStackPreviewView.swift` | 7 | 4 | mixed |
| `PepBox/BasketState.swift` | 0 | 0 | clean |
| `PepBox/BasketSwitcherView.swift` | 20 | 8 | mixed |
| `PepBox/BatteryHUDView.swift` | 1 | 0 | ssot-only |
| `PepBox/BatteryManager.swift` | 0 | 0 | clean |
| `PepBox/BrightnessManager.swift` | 0 | 0 | clean |
| `PepBox/CachedAsyncImage.swift` | 0 | 0 | clean |
| `PepBox/CapsLockHUDView.swift` | 1 | 0 | ssot-only |
| `PepBox/CapsLockManager.swift` | 0 | 0 | clean |
| `PepBox/ClipboardManager.swift` | 2 | 0 | ssot-only |
| `PepBox/ClipboardManagerView.swift` | 71 | 21 | mixed |
| `PepBox/ClipboardWindowController.swift` | 0 | 0 | clean |
| `PepBox/ContentView.swift` | 0 | 0 | clean |
| `PepBox/CrashReporter.swift` | 0 | 0 | clean |
| `PepBox/DNDHUDView.swift` | 1 | 0 | ssot-only |
| `PepBox/DNDManager.swift` | 0 | 0 | clean |
| `PepBox/DestinationManager.swift` | 0 | 0 | clean |
| `PepBox/DragMonitor.swift` | 0 | 0 | clean |
| `PepBox/DraggableArea.swift` | 0 | 0 | clean |
| `PepBox/DraggableItemWrapper.swift` | 0 | 0 | clean |
| `PepBox/DropZoneIcon.swift` | 1 | 0 | ssot-only |
| `PepBox/DroppedItem.swift` | 0 | 0 | clean |
| `PepBox/DroppedItemView.swift` | 9 | 2 | mixed |
| `PepBox/PepBoxAlertView.swift` | 2 | 2 | raw-only |
| `PepBox/PepBoxAnimation.swift` | 85 | 0 | ssot-only |
| `PepBox/PepBoxApp.swift` | 0 | 0 | clean |
| `PepBox/PepBoxButtonStyle.swift` | 17 | 0 | ssot-only |
| `PepBox/PepBoxDesign.swift` | 6 | 6 | raw-only |
| `PepBox/PepBoxNotifications.swift` | 0 | 0 | clean |
| `PepBox/PepBoxQuickshare.swift` | 0 | 0 | clean |
| `PepBox/PepBoxState.swift` | 2 | 0 | ssot-only |
| `PepBox/ExtensionInfoView.swift` | 0 | 0 | clean |
| `PepBox/ExtensionReviewViews.swift` | 3 | 1 | mixed |
| `PepBox/Extensions/AIBackgroundRemoval/AIBackgroundRemovalCard.swift` | 0 | 0 | clean |
| `PepBox/Extensions/AIBackgroundRemoval/AIBackgroundRemovalExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/AIBackgroundRemoval/AIInstallComponents.swift` | 10 | 6 | mixed |
| `PepBox/Extensions/AIBackgroundRemoval/AIInstallManager.swift` | 0 | 0 | clean |
| `PepBox/Extensions/AIBackgroundRemoval/AIInstallView.swift` | 5 | 1 | mixed |
| `PepBox/Extensions/AIBackgroundRemoval/BackgroundRemovalManager.swift` | 0 | 0 | clean |
| `PepBox/Extensions/Alfred/AlfredCard.swift` | 0 | 0 | clean |
| `PepBox/Extensions/Alfred/AlfredExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/AppleMusic/AppleMusicController.swift` | 0 | 0 | clean |
| `PepBox/Extensions/AppleMusic/AppleMusicExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/Caffeine/CaffeineExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/Caffeine/CaffeineInfoView.swift` | 0 | 0 | clean |
| `PepBox/Extensions/Caffeine/CaffeineManager.swift` | 0 | 0 | clean |
| `PepBox/Extensions/Caffeine/CaffeineNotchView.swift` | 5 | 1 | mixed |
| `PepBox/Extensions/Caffeine/HighAlertHUDView.swift` | 0 | 0 | clean |
| `PepBox/Extensions/Camera/CameraExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/Camera/CameraInfoView.swift` | 0 | 0 | clean |
| `PepBox/Extensions/Camera/CameraManager.swift` | 0 | 0 | clean |
| `PepBox/Extensions/Camera/SnapCameraShelfPanel.swift` | 0 | 0 | clean |
| `PepBox/Extensions/PepBoxLoadableExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/ElementCapture/AreaSelectionWindow.swift` | 0 | 0 | clean |
| `PepBox/Extensions/ElementCapture/CapturePreviewView.swift` | 1 | 1 | raw-only |
| `PepBox/Extensions/ElementCapture/ElementCaptureCard.swift` | 0 | 0 | clean |
| `PepBox/Extensions/ElementCapture/ElementCaptureExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/ElementCapture/ElementCaptureInfoView.swift` | 1 | 0 | ssot-only |
| `PepBox/Extensions/ElementCapture/ElementCaptureManager.swift` | 2 | 2 | raw-only |
| `PepBox/Extensions/ElementCapture/ScreenshotEditorView.swift` | 1 | 1 | raw-only |
| `PepBox/Extensions/ElementCapture/ScreenshotEditorWindowController.swift` | 0 | 0 | clean |
| `PepBox/Extensions/ExtensionDefinition.swift` | 0 | 0 | clean |
| `PepBox/Extensions/ExtensionProtocol.swift` | 0 | 0 | clean |
| `PepBox/Extensions/FFmpegVideoCompression/FFmpegInstallManager.swift` | 0 | 0 | clean |
| `PepBox/Extensions/FFmpegVideoCompression/FFmpegInstallView.swift` | 7 | 1 | mixed |
| `PepBox/Extensions/FFmpegVideoCompression/FFmpegVideoCompressionCard.swift` | 0 | 0 | clean |
| `PepBox/Extensions/FFmpegVideoCompression/VideoTargetSizeExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/FinderServices/FinderServicesCard.swift` | 0 | 0 | clean |
| `PepBox/Extensions/FinderServices/FinderServicesExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/MenuBarManager/MenuBarManagerCard.swift` | 0 | 0 | clean |
| `PepBox/Extensions/MenuBarManager/MenuBarManagerExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/MenuBarManager/MenuBarManagerInfoView.swift` | 0 | 0 | clean |
| `PepBox/Extensions/MenuBarManager/MenuBarManagerManager.swift` | 0 | 0 | clean |
| `PepBox/Extensions/NotificationHUD/NotificationHUDExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/NotificationHUD/NotificationHUDInfoView.swift` | 0 | 0 | clean |
| `PepBox/Extensions/NotificationHUD/NotificationHUDManager.swift` | 0 | 0 | clean |
| `PepBox/Extensions/NotificationHUD/NotificationHUDView.swift` | 12 | 6 | mixed |
| `PepBox/Extensions/Quickshare/QuickshareExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/Quickshare/QuickshareInfoView.swift` | 0 | 0 | clean |
| `PepBox/Extensions/RemoveExtensionButton.swift` | 0 | 0 | clean |
| `PepBox/Extensions/Spotify/SpotifyAuthManager.swift` | 0 | 0 | clean |
| `PepBox/Extensions/Spotify/SpotifyCard.swift` | 0 | 0 | clean |
| `PepBox/Extensions/Spotify/SpotifyExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/TerminalNotch/TermiNotchExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/TerminalNotch/TerminalNotchButton.swift` | 0 | 0 | clean |
| `PepBox/Extensions/TerminalNotch/TerminalNotchCard.swift` | 0 | 0 | clean |
| `PepBox/Extensions/TerminalNotch/TerminalNotchInfoView.swift` | 0 | 0 | clean |
| `PepBox/Extensions/TerminalNotch/TerminalNotchManager.swift` | 4 | 1 | mixed |
| `PepBox/Extensions/TerminalNotch/TerminalNotchView.swift` | 2 | 1 | mixed |
| `PepBox/Extensions/ToDo/ToDoExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/ToDo/ToDoInfoView.swift` | 2 | 0 | ssot-only |
| `PepBox/Extensions/ToDo/ToDoManager.swift` | 12 | 12 | raw-only |
| `PepBox/Extensions/ToDo/ToDoShelfBar.swift` | 29 | 11 | mixed |
| `PepBox/Extensions/ToDo/ToDoUndoToast.swift` | 0 | 0 | clean |
| `PepBox/Extensions/ToDo/ToDoView.swift` | 9 | 9 | raw-only |
| `PepBox/Extensions/VoiceTranscribe/VoiceRecordingWindow.swift` | 4 | 3 | mixed |
| `PepBox/Extensions/VoiceTranscribe/VoiceTranscribeCard.swift` | 0 | 0 | clean |
| `PepBox/Extensions/VoiceTranscribe/VoiceTranscribeExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/VoiceTranscribe/VoiceTranscribeInfoView.swift` | 1 | 0 | ssot-only |
| `PepBox/Extensions/VoiceTranscribe/VoiceTranscribeManager.swift` | 0 | 0 | clean |
| `PepBox/Extensions/VoiceTranscribe/VoiceTranscribeMenuBar.swift` | 0 | 0 | clean |
| `PepBox/Extensions/VoiceTranscribe/VoiceTranscriptionResultView.swift` | 1 | 0 | ssot-only |
| `PepBox/Extensions/WindowSnap/SnapPreviewWindow.swift` | 0 | 0 | clean |
| `PepBox/Extensions/WindowSnap/WindowSnapCard.swift` | 0 | 0 | clean |
| `PepBox/Extensions/WindowSnap/WindowSnapExtension.swift` | 0 | 0 | clean |
| `PepBox/Extensions/WindowSnap/WindowSnapInfoView.swift` | 2 | 0 | ssot-only |
| `PepBox/Extensions/WindowSnap/WindowSnapManager.swift` | 0 | 0 | clean |
| `PepBox/ExtensionsShopView.swift` | 9 | 1 | mixed |
| `PepBox/FileCompressor.swift` | 0 | 0 | clean |
| `PepBox/FileConverter.swift` | 0 | 0 | clean |
| `PepBox/FilePromiseDropView.swift` | 0 | 0 | clean |
| `PepBox/FinderFolderDetector.swift` | 0 | 0 | clean |
| `PepBox/FinderServicesSetupView.swift` | 4 | 0 | ssot-only |
| `PepBox/FloatingBasketView.swift` | 22 | 5 | mixed |
| `PepBox/FloatingBasketWindowController.swift` | 0 | 0 | clean |
| `PepBox/FolderIcon.swift` | 1 | 1 | raw-only |
| `PepBox/FolderPreviewPopover.swift` | 0 | 0 | clean |
| `PepBox/GlobalHotKey.swift` | 0 | 0 | clean |
| `PepBox/HUDComponents.swift` | 16 | 3 | mixed |
| `PepBox/HUDLayoutCalculator.swift` | 0 | 0 | clean |
| `PepBox/HUDManager.swift` | 3 | 0 | ssot-only |
| `PepBox/HUDOverlayView.swift` | 8 | 3 | mixed |
| `PepBox/HapticFeedback.swift` | 0 | 0 | clean |
| `PepBox/HexagonDotsEffect.swift` | 1 | 1 | raw-only |
| `PepBox/HideNotchManager.swift` | 0 | 0 | clean |
| `PepBox/KeyShortcutRecorder.swift` | 0 | 0 | clean |
| `PepBox/LicenseActivationView.swift` | 10 | 8 | mixed |
| `PepBox/LicenseManager.swift` | 0 | 0 | clean |
| `PepBox/LicenseSettingsSection.swift` | 4 | 2 | mixed |
| `PepBox/LicenseUIComponents.swift` | 3 | 2 | mixed |
| `PepBox/LicenseWindowController.swift` | 0 | 0 | clean |
| `PepBox/LinkPreviewService.swift` | 0 | 0 | clean |
| `PepBox/LiquidGlassStyle.swift` | 4 | 0 | ssot-only |
| `PepBox/LiquidSlider.swift` | 2 | 0 | ssot-only |
| `PepBox/LockScreenHUDView.swift` | 7 | 7 | raw-only |
| `PepBox/LockScreenHUDWindowManager.swift` | 4 | 1 | mixed |
| `PepBox/LockScreenManager.swift` | 2 | 2 | raw-only |
| `PepBox/LockScreenMediaPanelManager.swift` | 0 | 0 | clean |
| `PepBox/LockScreenMediaPanelView.swift` | 1 | 0 | ssot-only |
| `PepBox/MailHelper.swift` | 0 | 0 | clean |
| `PepBox/MediaKeyInterceptor.swift` | 0 | 0 | clean |
| `PepBox/MediaPlayerComponents.swift` | 25 | 10 | mixed |
| `PepBox/MediaPlayerView.swift` | 25 | 3 | mixed |
| `PepBox/MusicManager.swift` | 0 | 0 | clean |
| `PepBox/NotchDragContainer.swift` | 8 | 1 | mixed |
| `PepBox/NotchFace.swift` | 5 | 2 | mixed |
| `PepBox/NotchItemView.swift` | 24 | 7 | mixed |
| `PepBox/NotchLayoutConstants.swift` | 0 | 0 | clean |
| `PepBox/NotchShelfView.swift` | 96 | 90 | mixed |
| `PepBox/NotchWindowController.swift` | 13 | 4 | mixed |
| `PepBox/OCRResultView.swift` | 1 | 0 | ssot-only |
| `PepBox/OCRService.swift` | 0 | 0 | clean |
| `PepBox/OCRWindowController.swift` | 0 | 0 | clean |
| `PepBox/OnboardingComponents.swift` | 7 | 4 | mixed |
| `PepBox/OnboardingView.swift` | 22 | 4 | mixed |
| `PepBox/Parallax3DModifier.swift` | 2 | 1 | mixed |
| `PepBox/PermissionManager.swift` | 0 | 0 | clean |
| `PepBox/PoofEffect.swift` | 7 | 1 | mixed |
| `PepBox/QuickLookHelper.swift` | 0 | 0 | clean |
| `PepBox/QuickShareSuccessView.swift` | 7 | 3 | mixed |
| `PepBox/QuickshareItem.swift` | 0 | 0 | clean |
| `PepBox/QuickshareManager.swift` | 0 | 0 | clean |
| `PepBox/QuickshareManagerView.swift` | 1 | 0 | ssot-only |
| `PepBox/QuickshareManagerWindowController.swift` | 0 | 0 | clean |
| `PepBox/QuickshareMenuContent.swift` | 0 | 0 | clean |
| `PepBox/QuickshareSettingsContent.swift` | 0 | 0 | clean |
| `PepBox/RenameWindowController.swift` | 0 | 0 | clean |
| `PepBox/RenameWindowView.swift` | 0 | 0 | clean |
| `PepBox/ReorderSheetView.swift` | 12 | 2 | mixed |
| `PepBox/ServiceProvider.swift` | 0 | 0 | clean |
| `PepBox/SettingsPreviewViews.swift` | 17 | 7 | mixed |
| `PepBox/SettingsSidebarItem.swift` | 3 | 0 | ssot-only |
| `PepBox/SettingsView.swift` | 8 | 0 | ssot-only |
| `PepBox/SettingsWindowController.swift` | 0 | 0 | clean |
| `PepBox/SharedComponents.swift` | 31 | 0 | ssot-only |
| `PepBox/SharedPepBoxComponents.swift` | 2 | 2 | raw-only |
| `PepBox/ShelfQuickActionsBar.swift` | 15 | 4 | mixed |
| `PepBox/ShelfView.swift` | 9 | 2 | mixed |
| `PepBox/SmartExportManager.swift` | 0 | 0 | clean |
| `PepBox/SmartExportSettingsView.swift` | 2 | 1 | mixed |
| `PepBox/SpotifyController.swift` | 0 | 0 | clean |
| `PepBox/SystemAudioAnalyzer.swift` | 0 | 0 | clean |
| `PepBox/TargetSizeDialog.swift` | 0 | 0 | clean |
| `PepBox/TemporaryFileStorageService.swift` | 0 | 0 | clean |
| `PepBox/ThumbnailCache.swift` | 0 | 0 | clean |
| `PepBox/TrackedFoldersManager.swift` | 0 | 0 | clean |
| `PepBox/URLSchemeHandler.swift` | 0 | 0 | clean |
| `PepBox/UpdateChecker.swift` | 0 | 0 | clean |
| `PepBox/UpdateHUDView.swift` | 1 | 0 | ssot-only |
| `PepBox/UpdateView.swift` | 0 | 0 | clean |
| `PepBox/UpdateWindowController.swift` | 0 | 0 | clean |
| `PepBox/UserPreferences.swift` | 0 | 0 | clean |
| `PepBox/Utilities/CGSShims.swift` | 0 | 0 | clean |
| `PepBox/VolumeManager.swift` | 0 | 0 | clean |

## Top Raw Hotspots

| File | Raw Sites |
|---|---:|
| `PepBox/NotchShelfView.swift` | 90 |
| `PepBox/ClipboardManagerView.swift` | 21 |
| `PepBox/Extensions/ToDo/ToDoManager.swift` | 12 |
| `PepBox/Extensions/ToDo/ToDoShelfBar.swift` | 11 |
| `PepBox/BasketItemView.swift` | 11 |
| `PepBox/MediaPlayerComponents.swift` | 10 |
| `PepBox/Extensions/ToDo/ToDoView.swift` | 9 |
| `PepBox/LicenseActivationView.swift` | 8 |
| `PepBox/BasketSwitcherView.swift` | 8 |
| `PepBox/SettingsPreviewViews.swift` | 7 |
| `PepBox/NotchItemView.swift` | 7 |
| `PepBox/LockScreenHUDView.swift` | 7 |
| `PepBox/Extensions/NotificationHUD/NotificationHUDView.swift` | 6 |
| `PepBox/Extensions/AIBackgroundRemoval/AIInstallComponents.swift` | 6 |
| `PepBox/PepBoxDesign.swift` | 6 |
| `PepBox/AirPodsHUDView.swift` | 6 |
| `PepBox/FloatingBasketView.swift` | 5 |
| `PepBox/ShelfQuickActionsBar.swift` | 4 |
| `PepBox/OnboardingView.swift` | 4 |
| `PepBox/OnboardingComponents.swift` | 4 |
| `PepBox/NotchWindowController.swift` | 4 |
| `PepBox/BasketStackPreviewView.swift` | 4 |
| `PepBox/QuickShareSuccessView.swift` | 3 |
| `PepBox/MediaPlayerView.swift` | 3 |
| `PepBox/HUDOverlayView.swift` | 3 |
| `PepBox/HUDComponents.swift` | 3 |
| `PepBox/Extensions/VoiceTranscribe/VoiceRecordingWindow.swift` | 3 |
| `PepBox/ShelfView.swift` | 2 |
| `PepBox/SharedPepBoxComponents.swift` | 2 |
| `PepBox/ReorderSheetView.swift` | 2 |
| `PepBox/NotchFace.swift` | 2 |
| `PepBox/LockScreenManager.swift` | 2 |
| `PepBox/LicenseUIComponents.swift` | 2 |
| `PepBox/LicenseSettingsSection.swift` | 2 |
| `PepBox/Extensions/ElementCapture/ElementCaptureManager.swift` | 2 |
| `PepBox/PepBoxAlertView.swift` | 2 |
| `PepBox/DroppedItemView.swift` | 2 |
| `PepBox/AppKitMotion.swift` | 2 |
| `PepBox/SmartExportSettingsView.swift` | 1 |
| `PepBox/PoofEffect.swift` | 1 |

## Top Hardcoded Primitive Hotspots

| File | Primitive Sites |
|---|---:|
| `PepBox/MediaPlayerComponents.swift` | 9 |
| `PepBox/BasketSwitcherView.swift` | 8 |
| `PepBox/SettingsPreviewViews.swift` | 7 |
| `PepBox/LockScreenHUDView.swift` | 7 |
| `PepBox/Extensions/ToDo/ToDoShelfBar.swift` | 6 |
| `PepBox/PepBoxDesign.swift` | 6 |
| `PepBox/Extensions/ToDo/ToDoView.swift` | 5 |
| `PepBox/BasketItemView.swift` | 5 |
| `PepBox/NotchShelfView.swift` | 4 |
| `PepBox/NotchItemView.swift` | 4 |
| `PepBox/Extensions/NotificationHUD/NotificationHUDView.swift` | 4 |
| `PepBox/ClipboardManagerView.swift` | 4 |
| `PepBox/BasketStackPreviewView.swift` | 4 |
| `PepBox/AirPodsHUDView.swift` | 4 |
| `PepBox/QuickShareSuccessView.swift` | 3 |
| `PepBox/OnboardingComponents.swift` | 3 |
| `PepBox/SharedPepBoxComponents.swift` | 2 |
| `PepBox/ReorderSheetView.swift` | 2 |
| `PepBox/OnboardingView.swift` | 2 |
| `PepBox/NotchWindowController.swift` | 2 |
| `PepBox/LicenseActivationView.swift` | 2 |
| `PepBox/FloatingBasketView.swift` | 2 |
| `PepBox/Extensions/VoiceTranscribe/VoiceRecordingWindow.swift` | 2 |
| `PepBox/Extensions/ElementCapture/ElementCaptureManager.swift` | 2 |
| `PepBox/PepBoxAlertView.swift` | 2 |
| `PepBox/AppKitMotion.swift` | 2 |
| `PepBox/SmartExportSettingsView.swift` | 1 |
| `PepBox/PoofEffect.swift` | 1 |
| `PepBox/Parallax3DModifier.swift` | 1 |
| `PepBox/MediaPlayerView.swift` | 1 |
| `PepBox/LockScreenHUDWindowManager.swift` | 1 |
| `PepBox/LicenseUIComponents.swift` | 1 |
| `PepBox/HUDOverlayView.swift` | 1 |
| `PepBox/HUDComponents.swift` | 1 |
| `PepBox/Extensions/TerminalNotch/TerminalNotchView.swift` | 1 |
| `PepBox/Extensions/TerminalNotch/TerminalNotchManager.swift` | 1 |
| `PepBox/Extensions/FFmpegVideoCompression/FFmpegInstallView.swift` | 1 |
| `PepBox/Extensions/ElementCapture/ScreenshotEditorView.swift` | 1 |
| `PepBox/Extensions/ElementCapture/CapturePreviewView.swift` | 1 |
| `PepBox/Extensions/AIBackgroundRemoval/AIInstallView.swift` | 1 |
