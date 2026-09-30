//
//  CaffeineInfoView.swift
//  PepBox
//

import SwiftUI

struct CaffeineInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    var caffeineManager = CaffeineManager.shared
    
    @AppStorage(AppPreferenceKey.caffeineInstalled) private var isInstalled = PreferenceDefault.caffeineInstalled
    @AppStorage(AppPreferenceKey.caffeineMode) private var selectedModeRaw = PreferenceDefault.caffeineMode
    
    // Derived mode from preference
    private var selectedMode: CaffeineMode {
        get { CaffeineMode(rawValue: selectedModeRaw) ?? .both }
    }
    
    // Stats passed from parent
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (fixed)
            headerSection
            
            Divider()
                .padding(.horizontal, 24)
            
            // Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Features & Screenshot
                    featuresSection
                    
                    // Controls Card
                    controlsSection
                    
                    // Mode Selection
                    modeSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxHeight: 500)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Footer (fixed)
            footerSection
        }
        .frame(width: 450)
        .fixedSize(horizontal: true, vertical: true)
        .pepboxSurface(transparent: useTransparentBackground)
        .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.xl, style: .continuous))
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            CachedAsyncImage(url: URL(string: "pepbox-media://icons/high-alert.jpg")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "eyes").font(.system(size: 32)).foregroundStyle(.orange)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.large, style: .continuous))
            .shadow(color: .orange.opacity(0.4), radius: 8, y: 4)
            
            Text("High Alert")
                .font(.title2.bold())
            
            // Stats Row
            HStack(spacing: 12) {
                
                // Category Badge
                Text("Productivity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
            }
            
            Text("Prevent your Mac from sleeping")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Community Extension Badge
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                Text("Community Extension")
                    .font(.caption.weight(.medium))
                Text("by")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Link("Valetivivek", destination: URL(string: "https://github.com/valetivivek")!)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.purple.opacity(0.12)))
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Features
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "eyes", text: "Keep system awake indefinitely")
            featureRow(icon: "timer", text: "Timed modes (15m, 1h, etc)")
            featureRow(icon: "bolt.fill", text: "Low resource usage")
            
            // Screenshot (animated GIF)
            AnimatedGIFView(url: "pepbox-media://images/high-alert-screenshot.gif")
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PepBoxRadius.medium, style: .continuous)
                        .strokeBorder(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                )
                .padding(.top, 8)
        }
        // Left-align and fill parent width
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.orange)
                .frame(width: 24)
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Status Banner
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(caffeineManager.isActive ? .green : .gray)
                            .frame(width: 8, height: 8)
                        Text(caffeineManager.isActive ? "Active" : "Inactive")
                            .font(.headline)
                            .foregroundStyle(caffeineManager.isActive ? .green : .primary)
                    }
                    
                    if caffeineManager.isActive {
                        Text(caffeineManager.currentDuration == .indefinite ? "Running indefinitely" : "Time remaining: \(caffeineManager.formattedRemaining)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } else {
                        Text("System sleep enabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Big Toggle Button
                Button {
                    HapticFeedback.drop()
                    caffeineManager.toggle(duration: .indefinite, mode: selectedMode)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(PepBoxCircleButtonStyle(size: 36, solidFill: caffeineManager.isActive ? .green : nil))
            }
            .padding(PepBoxSpacing.lg)
            .background(AdaptiveColors.buttonBackgroundAuto.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PepBoxRadius.large, style: .continuous)
                    .stroke(caffeineManager.isActive ? Color.green.opacity(0.3) : AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
            
            // Timers Grid
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Timers")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                    timerButton(.indefinite)
                    ForEach(CaffeineDuration.minutePresets, id: \.id) { timerButton($0) }
                    ForEach(CaffeineDuration.hourPresets, id: \.id) { timerButton($0) }
                }
            }
        }
    }
    
    private func timerButton(_ duration: CaffeineDuration) -> some View {
        let isActive = caffeineManager.isActive && caffeineManager.currentDuration == duration
        return Button {
            HapticFeedback.tap()
            caffeineManager.activate(duration: duration, mode: selectedMode)
        } label: {
            Text(duration.shortLabel)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(isActive 
                     ? AnyButtonStyle(PepBoxAccentButtonStyle(color: .orange, size: .small))
                     : AnyButtonStyle(PepBoxPillButtonStyle(size: .small)))
    }
    
    // MARK: - Mode
    
    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prevention Mode")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 0) {
                ForEach(Array(CaffeineMode.allCases.enumerated()), id: \.element) { index, mode in
                    let isSelected = selectedMode == mode
                    Button {
                        HapticFeedback.tap()
                        selectedModeRaw = mode.rawValue
                        if caffeineManager.isActive {
                            // Update active session on change
                            caffeineManager.activate(duration: caffeineManager.currentDuration, mode: mode)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.rawValue)
                                    .font(.callout.weight(.medium))
                                Text(mode.description)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isSelected {
                                    Image(systemName: "checkmark")
                                    .foregroundStyle(.orange)
                                    .font(.caption.weight(.bold))
                            }
                        }
                        .padding(PepBoxSpacing.md)
                        .background(isSelected ? AdaptiveColors.buttonBackgroundAuto : Color.clear)
                    }
                    .buttonStyle(.plain)
                    
                    if index < CaffeineMode.allCases.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(AdaptiveColors.overlayAuto(0.03))
            .clipShape(RoundedRectangle(cornerRadius: PepBoxRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PepBoxRadius.large, style: .continuous)
                    .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        HStack {
            Button("Close") { dismiss() }
                .buttonStyle(PepBoxPillButtonStyle(size: .small))
            
            Spacer()
            
            if isInstalled {
                DisableExtensionButton(extensionType: .caffeine)
            } else {
                Button {
                    installExtension()
                } label: {
                    Text("Install")
                }
                .buttonStyle(PepBoxAccentButtonStyle(color: .orange, size: .small))
            }
        }
        .padding(PepBoxSpacing.lg)
    }
    
    // MARK: - Actions
    
    private func installExtension() {
        isInstalled = true
        caffeineManager.isInstalled = true
        ExtensionType.caffeine.setRemoved(false)
        
        // Track installation
        Task {
            AnalyticsService.shared.trackExtensionActivation(extensionId: "caffeine")
        }
        
        // Post notification
        NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.caffeine)
    }
}

#Preview {
    CaffeineInfoView()
}
