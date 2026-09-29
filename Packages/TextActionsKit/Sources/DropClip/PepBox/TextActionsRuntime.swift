//
//  TextActionsRuntime.swift
//  Text Actions (DropClip in PepBox)
//
//  Starts and stops DropClip inside PepBox. Ported from DropClip's
//  `DropClipDroplet.swift` (which was upstream OpenClip's app delegate) with the
//  Droppy host removed: no DroppyKit, no Droppy settings pages or shortcuts page,
//  no OpenClip/Droppy settings migration. Settings open DropClip's own window.
//

import AppKit
import DropClipCore
import OpenSelection
import SwiftUI

/// PepBox's entry points.
@MainActor
public enum TextActions {
    /// Starts watching selections (or resumes after `stop()`).
    public static func start() { DropClipRuntime.shared.activate() }

    /// Suspends everything: the popup, the selection monitor, hotkeys, extensions.
    public static func stop() { DropClipRuntime.shared.deactivate() }

    /// Opens Text Actions' settings window.
    public static func openSettings() { DropClipRuntime.shared.openSettings() }

    public static var isRunning: Bool { DropClipRuntime.shared.state == .running }
}

/// DropClip starts once per launch. Stopping suspends it (Swift can't unload code);
/// starting again resumes it.
@MainActor
final class DropClipRuntime {
    static let shared = DropClipRuntime()

    enum State { case idle, running, suspended }

    private(set) var state: State = .idle

    private var selectionMonitor: MacSelectionMonitor?
    private(set) var popupController: PopupWindowController?
    private var aiActionSync: AIActionSync?
    private var extensionsWatcher: ExtensionsDirectoryWatcher?
    private var onboardingWindowController: OnboardingWindowController?
    private var permissionRecoveryWindowController: PermissionRecoveryWindowController?
    private var coachMarkController: CoachMarkController?
    private var observers: [NSObjectProtocol] = []
    private var pauseTask: Task<Void, Never>?

    func activate() {
        switch state {
        case .idle:
            state = .running
            start()
        case .suspended:
            state = .running
            resume()
        case .running:
            return
        }
    }

    func deactivate() {
        guard state == .running else { return }
        state = .suspended
        suspend()
    }

    // MARK: Start (upstream's applicationDidFinishLaunching)

    private func start() {
        let rotatingSink = RotatingFileLogSink()
        RotatingFileLogSink.shared = rotatingSink
        Log.addSink(rotatingSink)
        _ = DebugLogStore.shared

        OpenSelection.logger = { message in
            Log.selection.debug("\(message, privacy: .public)")
        }

        DefaultActionResultHandler.purgeStaleCalendarTempFiles()

        DeepLinkRouter.shared.configure {
            DropClipRuntime.shared.openSettings()
        }

        let controller = PopupWindowController()
        popupController = controller

        let macMonitor = MacSelectionMonitor()
        macMonitor.onSelection = { [weak self] context, canPaste in
            guard let self, self.state == .running else { return }
            let isPaused = DefaultSettingsStore.shared.get(.pauseUntilTimestamp) > Date().timeIntervalSince1970
            if !isPaused {
                self.coachMarkController?.dismiss()
                self.popupController?.show(for: context, pasteAvailable: canPaste)
            }
        }
        macMonitor.preparePasteProbe = { [weak self] app, policy in
            self?.popupController?.preparePasteProbe(for: app, policy: policy)
        }
        macMonitor.isSuppressedForApp = { [weak self] bundleID in
            guard let self, let popup = self.popupController, popup.cardIsModal,
                  let source = popup.sourceAppBundleID, let bundleID else { return false }
            return bundleID == source
        }
        selectionMonitor = macMonitor

        HotkeyManager.shared.setup(popupController: controller, selectionMonitor: macMonitor)

        Task {
            let optionStore = SecretActionOptionStore()
            ExtensionManager.shared.actionFactory = DefaultActionFactory(optionStore: optionStore)
            ExtensionManager.shared.optionWriter = optionStore
            ExtensionManager.shared.optionReader = optionStore
            ExtensionManager.shared.settingsStore = DefaultSettingsStore.shared
            CustomActionJSRunnerRegistry.runner = DefaultCustomActionJSRunner()
            await ActionCoordinator.shared.loadInitialState(
                dictionaryLookup: DictionaryLookupFactory.systemLookup
            )
            ActionCoordinator.shared.register(action: OpenURLAction())
            ActionCoordinator.shared.register(action: RevealInFinderAction())
            ActionCoordinator.shared.register(action: CompletionAction())
            aiActionSync = AIActionSync.shared
            startExtensionWatcher()
        }

        observeNotifications()
        schedulePauseEndIfNeeded()
        classifyLaunch()
    }

    private func classifyLaunch() {
        let currentVersion = Bundle.dropclip.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let currentBuild = Bundle.dropclip.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let lastRunVersion = DefaultSettingsStore.shared.get(.lastRunVersion)
        let lastRunBuild = DefaultSettingsStore.shared.get(.lastRunBuild)
        let completedOnboarding = DefaultSettingsStore.shared.get(.hasCompletedOnboarding)
        let isGranted = PermissionManager.shared.isAccessibilityGranted

        let launchScenario = AppLaunchClassifier.classify(
            lastRunVersion: lastRunVersion,
            currentVersion: currentVersion,
            lastRunBuild: lastRunBuild,
            currentBuild: currentBuild,
            hasCompletedOnboarding: completedOnboarding,
            isAccessibilityGranted: isGranted
        )

        switch launchScenario {
        case .firstInstall:
            showOnboarding()
        case .appUpdate:
            recordCurrentVersion()
            if isGranted {
                selectionMonitor?.start()
            } else {
                showPermissionRecovery(isUpdate: true)
            }
        case .permissionRecovery:
            showPermissionRecovery(isUpdate: false)
        case .normalLaunch:
            if lastRunVersion != currentVersion || lastRunBuild != currentBuild {
                recordCurrentVersion()
            }
            if isGranted {
                selectionMonitor?.start()
            }
        }
    }

    private func observeNotifications() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .dropClipShowSandboxPopup, object: nil, queue: .main) { notification in
            guard let context = notification.object as? SelectionContext else { return }
            DroppyMainThread.enter {
                DropClipRuntime.shared.popupController?.show(for: context, pasteAvailable: false)
            }
        })
        observers.append(center.addObserver(forName: .dropClipAccessibilityChanged, object: nil, queue: .main) { notification in
            let granted = notification.object as? Bool
            DroppyMainThread.enter {
                let runtime = DropClipRuntime.shared
                guard runtime.state == .running else { return }
                if granted ?? PermissionManager.shared.isAccessibilityGranted {
                    runtime.selectionMonitor?.start()
                } else {
                    runtime.selectionMonitor?.stop()
                }
            }
        })
        observers.append(center.addObserver(forName: .dropClipOpenActionConfiguration, object: nil, queue: .main) { notification in
            let request = notification.userInfo?["request"] as? ConfigurationRequest
            DroppyMainThread.enter {
                guard let request,
                      let action = ActionCoordinator.shared.actions.first(where: { $0.id == request.actionID })
                else {
                    DropClipRuntime.shared.openSettings()
                    return
                }
                SettingsRouter.shared.openConfiguration(for: action, request: request)
            }
        })
    }

    // MARK: Suspend and resume

    private func suspend() {
        popupController?.hide()
        onboardingWindowController?.close()
        onboardingWindowController = nil
        permissionRecoveryWindowController?.close()
        permissionRecoveryWindowController = nil
        popupController?.isOnboardingVisible = false
        coachMarkController?.dismiss()
        selectionMonitor?.stop()
        PermissionManager.shared.stopMonitoring()
        pauseTask?.cancel()
        pauseTask = nil
        KeyboardShortcuts.isEnabled = false
        extensionsWatcher?.stop()
    }

    private func resume() {
        KeyboardShortcuts.isEnabled = true
        startExtensionWatcher()
        schedulePauseEndIfNeeded()
        PermissionManager.shared.checkStatus()
        if !DefaultSettingsStore.shared.get(.hasCompletedOnboarding) {
            showOnboarding()
        } else if PermissionManager.shared.isAccessibilityGranted {
            selectionMonitor?.start()
        } else {
            showPermissionRecovery(isUpdate: false)
        }
    }

    // MARK: Windows of its own

    private func showOnboarding() {
        popupController?.isOnboardingVisible = true
        onboardingWindowController = OnboardingWindowController {
            let runtime = DropClipRuntime.shared
            runtime.onboardingWindowController = nil
            runtime.popupController?.isOnboardingVisible = false
            guard runtime.state == .running else { return }
            if PermissionManager.shared.isAccessibilityGranted {
                runtime.selectionMonitor?.start()
            }
        }
        onboardingWindowController?.showWindow(nil)
    }

    private func showPermissionRecovery(isUpdate: Bool) {
        permissionRecoveryWindowController = PermissionRecoveryWindowController(
            isUpdate: isUpdate,
            onComplete: {
                let runtime = DropClipRuntime.shared
                runtime.permissionRecoveryWindowController = nil
                guard runtime.state == .running else { return }
                runtime.recordCurrentVersion()
                if PermissionManager.shared.isAccessibilityGranted {
                    runtime.selectionMonitor?.start()
                }
            },
            onDismiss: {
                let runtime = DropClipRuntime.shared
                runtime.permissionRecoveryWindowController = nil
                guard runtime.state == .running else { return }
                runtime.recordCurrentVersion()
            }
        )
        permissionRecoveryWindowController?.showWindow(nil)
    }

    private func recordCurrentVersion() {
        let currentVersion = Bundle.dropclip.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let currentBuild = Bundle.dropclip.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        DefaultSettingsStore.shared.set(.lastRunVersion, value: currentVersion)
        DefaultSettingsStore.shared.set(.lastRunBuild, value: currentBuild)
    }

    private func startExtensionWatcher() {
        guard state == .running else { return }
        if let extensionsWatcher {
            extensionsWatcher.start(watching: Constants.extensionsDirectory)
            return
        }
        let watcher = ExtensionsDirectoryWatcher {
            guard DropClipRuntime.shared.state == .running else { return }
            await ExtensionManager.shared.loadExtensions(from: Constants.extensionsDirectory)
        }
        watcher.start(watching: Constants.extensionsDirectory)
        extensionsWatcher = watcher
    }

    // MARK: Pause

    var pausedUntil: Date? {
        let until = DefaultSettingsStore.shared.get(.pauseUntilTimestamp)
        return until > Date().timeIntervalSince1970 ? Date(timeIntervalSince1970: until) : nil
    }

    func pause(for seconds: TimeInterval) {
        DefaultSettingsStore.shared.set(.pauseUntilTimestamp, value: Date().timeIntervalSince1970 + seconds)
        schedulePauseEnd(after: seconds)
        NotificationCenter.default.post(name: .dropClipEnabledStateChanged, object: nil)
    }

    func pauseUntilTomorrow() {
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(86400)
        pause(for: tomorrow.timeIntervalSince(now))
    }

    func resumeFromPause() {
        pauseTask?.cancel()
        pauseTask = nil
        DefaultSettingsStore.shared.set(.pauseUntilTimestamp, value: 0.0)
        NotificationCenter.default.post(name: .dropClipEnabledStateChanged, object: nil)
    }

    private func schedulePauseEndIfNeeded() {
        let remaining = DefaultSettingsStore.shared.get(.pauseUntilTimestamp) - Date().timeIntervalSince1970
        if remaining > 0 { schedulePauseEnd(after: remaining) }
    }

    private func schedulePauseEnd(after seconds: TimeInterval) {
        pauseTask?.cancel()
        pauseTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(max(0.1, seconds) * 1_000_000_000))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            DropClipRuntime.shared.resumeFromPause()
        }
    }

    // MARK: Settings

    func openSettings(page: SettingsPage? = nil) {
        SettingsWindowController.shared.present(tab: nil)
        if let page { SettingsRouter.shared.select(page) }
    }
}
