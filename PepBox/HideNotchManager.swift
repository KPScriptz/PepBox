//
//  HideNotchManager.swift
//  PepBox
//
//  Manages the "Hide Physical Notch" feature that draws a black bar
//  across the menu bar area to hide the notch cutout
//

import SwiftUI
import AppKit
import Combine

/// Manages the black bar window that hides the physical notch
/// Allows menu bar icons to use the space normally occupied by the notch
final class HideNotchManager: ObservableObject {
    static let shared = HideNotchManager()
    
    /// Windows for each display (keyed by display ID)
    private var hideNotchWindows: [CGDirectDisplayID: NSPanel] = [:]
    
    /// Whether the feature is currently active
    @Published private(set) var isActive: Bool = false
    
    /// Observer for screen configuration changes
    private var screenObserver: NSObjectProtocol?
    
    /// Observer for preference changes
    private var prefObserver: NSObjectProtocol?
    
    private init() {
        setupObservers()
    }
    
    deinit {
        disable()
        removeObservers()
    }
    
    // MARK: - Public API
    
    /// Enable the hide notch feature (show black bar on applicable displays)
    func enable() {
        guard hideNotchWindows.isEmpty else { 
            // Already enabled, just refresh
            refreshWindows()
            return 
        }
        
        createWindowsForApplicableDisplays()
        isActive = !hideNotchWindows.isEmpty
        
        if isActive {
            print("[HideNotch] Enabled - black bar(s) visible on \(hideNotchWindows.count) display(s)")
        } else {
            print("[HideNotch] No applicable displays found (Dynamic Island mode may be active)")
        }
    }
    
    /// Disable the hide notch feature (remove all black bars)
    func disable() {
        for window in hideNotchWindows.values {
            window.close()
        }
        hideNotchWindows.removeAll()
        isActive = false
        print("[HideNotch] Disabled - all black bars removed")
    }
    
    /// Refresh windows (call when display mode changes)
    func refreshWindows() {
        // Remove existing windows and recreate
        for window in hideNotchWindows.values {
            window.close()
        }
        hideNotchWindows.removeAll()
        
        if UserDefaults.standard.bool(forKey: AppPreferenceKey.hidePhysicalNotch) {
            createWindowsForApplicableDisplays()
            isActive = !hideNotchWindows.isEmpty
        }
    }
    
    // MARK: - Window Creation
    
    private func createWindowsForApplicableDisplays() {
        let includeExternals = UserDefaults.standard.bool(forKey: AppPreferenceKey.hidePhysicalNotchOnExternals)
        
        for screen in NSScreen.screens {
            // Check if this display should have a black bar
            if shouldCreateWindowForScreen(screen, includeExternals: includeExternals) {
                createWindow(for: screen)
            }
        }
    }
    
    /// Determines if a screen should have a hide notch window
    private func shouldCreateWindowForScreen(_ screen: NSScreen, includeExternals: Bool) -> Bool {
        let isBuiltIn = screen.isBuiltIn
        
        // For built-in display: only if it has a physical notch AND not in Dynamic Island mode
        if isBuiltIn {
            let hasPhysicalNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
            if !hasPhysicalNotch {
                return false
            }
            
            // Don't show in Dynamic Island mode - it doesn't make sense there
            let useDynamicIsland = UserDefaults.standard.bool(forKey: AppPreferenceKey.useDynamicIslandStyle)
            if useDynamicIsland {
                return false
            }
            
            return true
        }
        
        // For external displays: only if the sub-option is enabled AND not in Dynamic Island mode
        if includeExternals {
            // Check if external display is in notch mode (not Dynamic Island mode)
            let externalUseDynamicIsland = UserDefaults.standard.bool(forKey: AppPreferenceKey.externalDisplayUseDynamicIsland)
            if externalUseDynamicIsland {
                return false  // Dynamic Island mode - no black bar needed
            }
            
            return true
        }
        
        return false
    }
    
    private func createWindow(for screen: NSScreen) {
        let frame = calculateWindowFrame(for: screen)
        
        // Create a borderless panel
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Configure window properties
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.hasShadow = false
        
        // CRITICAL: Window level must be BELOW PepBox's notch windows (.statusBar)
        // but high enough to be above regular windows
        // Using .mainMenu level (23) - below statusBar (25) but above normal (0)
        panel.level = .mainMenu
        
        // Standard behaviors for system-wide visibility
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true  // Allow clicks to pass through
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        
        // Show the window
        panel.orderFrontRegardless()
        
        hideNotchWindows[screen.displayID] = panel
    }
    
    /// Calculate the frame for the black bar window
    /// Covers the entire menu bar area (full width, menu bar height)
    private func calculateWindowFrame(for screen: NSScreen) -> NSRect {
        let isBuiltIn = screen.isBuiltIn
        var barHeight: CGFloat
        
        if isBuiltIn {
            // For built-in: use notch height from safe area insets
            let hasPhysicalNotch = screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
            if hasPhysicalNotch && screen.safeAreaInsets.top > 0 {
                barHeight = screen.safeAreaInsets.top
            } else {
                barHeight = 37  // Standard notch height fallback
            }
        } else {
            // For external displays: use menu bar height
            // Menu bar height = difference between full frame and visible frame at the top
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            barHeight = menuBarHeight > 0 ? menuBarHeight : 24  // Fallback to 24pt
        }
        
        // Full width of screen, positioned at top
        return NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.maxY - barHeight,
            width: screen.frame.width,
            height: barHeight
        )
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        // Observe screen configuration changes (resolution, arrangement, connect/disconnect)
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }
        
        // Observe display mode preference changes
        prefObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Only refresh if feature is active and display mode changed
            guard let self = self, self.isActive else { return }
            self.refreshWindows()
        }
    }
    
    private func removeObservers() {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = prefObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func handleScreenChange() {
        guard isActive else { return }
        refreshWindows()
    }
}
