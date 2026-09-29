// Notification.Name+DropClip.swift
// DropClip
//
// Central registry of DropClip-specific Notification.Name values, replacing scattered inline string
// literals so presentation and composition code share one source of truth.
import Foundation

extension Notification.Name {
    /// Posted when an action requests its configuration UI. The popup hides first
    /// (`.openConfiguration` dismisses the popup); the payload `ConfigurationRequest` travels in
    /// `userInfo["request"]`. StatusBarController/Preferences observes this, finds the action by id
    /// in `ActionCoordinator.shared.actions`, and presents its `ActionEditorPage`.
    static let dropClipOpenActionConfiguration = Notification.Name("DropClipOpenActionConfiguration")

    /// Posted when extension packages are installed, uninstalled, enabled, or disabled.
    static let dropClipExtensionsDidChange = Notification.Name("DropClipExtensionsDidChange")

    /// Posted when the master app enabled state changes.
    static let dropClipEnabledStateChanged = Notification.Name("DropClipEnabledStateChanged")

    /// Posted when the user changes whether DropClip appears in the menu bar.
    static let dropClipMenuBarVisibilityChanged = Notification.Name("DropClipMenuBarVisibilityChanged")

    /// Posted when accessibility authorization changes. The new `Bool` status travels in `object`.
    static let dropClipAccessibilityChanged = Notification.Name("DropClipAccessibilityChanged")

    /// Posted when selection inside onboarding sandbox triggers a popup.
    static let dropClipShowSandboxPopup = Notification.Name("DropClipShowSandboxPopup")

    /// Posted to switch the active tab in the Preferences window. The target `PreferenceTab` travels in `object`.
    static let dropClipSelectPreferencesTab = Notification.Name("DropClipSelectPreferencesTab")

    /// Posted every time the Settings window is brought to the front (created or reused). The
    /// sidebar scrolls its selected row into view on this, because a reused window never sees
    /// `onAppear` again and the selection itself may not change.
    static let dropClipPreferencesWindowDidShow = Notification.Name("DropClipPreferencesWindowDidShow")
}
