//
//  ShelfQuickActionsBar.swift
//  PepBox
//
//  Quick Actions bar for shelf - appears when files are dragged
//  Same functionality as basket quick actions
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shelf Quick Actions Bar

struct ShelfQuickActionsBar: View {
    let items: [DroppedItem]
    /// Whether to use transparent styling (passed from parent based on actual shelf transparency)
    var useTransparent: Bool = false
    
    private let buttonSize: CGFloat = 32
    private let spacing: CGFloat = 12
    @State private var actions = QuickActionType.enabled
    @State private var isBarAreaTargeted = false  // Track when drag is over the bar area (between buttons)
    
    /// Computed width of bar area: one button per enabled action plus gaps
    private var barWidth: CGFloat {
        let actionCount = max(1, actions.count)
        return (buttonSize * CGFloat(actionCount)) + (spacing * CGFloat(actionCount - 1)) + 16
    }
    
    var body: some View {
        ZStack {
            // Transparent hit area background - captures drags between buttons
            Capsule()
                .fill(AdaptiveColors.overlayAuto(0.001)) // Nearly invisible but captures events
                .frame(width: barWidth, height: buttonSize + 8)
                // Track when drag is over the bar area
                .onDrop(of: [UTType.fileURL, UTType.image, UTType.movie, UTType.data], isTargeted: $isBarAreaTargeted) { _ in
                    return false  // Don't handle drop here
                }
                // Keep shelf quick actions state alive while drag is over bar area
                .onChange(of: isBarAreaTargeted) { _, targeted in
                    if targeted {
                        // Drag entered bar area
                        PepBoxState.shared.isShelfQuickActionsTargeted = true
                    }
                    // Don't clear on exit - buttons will handle that
                }
            
            HStack(spacing: spacing) {
                ForEach(Array(actions.enumerated()), id: \.element) { index, action in
                    ShelfQuickActionButton(actionType: action, useTransparent: useTransparent) { urls in
                        action.perform(urls)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity).animation(PepBoxAnimation.itemInsertion.delay(Double(index) * 0.03)),
                        removal: .scale(scale: 0.5).combined(with: .opacity).animation(PepBoxAnimation.hover)
                    ))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickActionsChanged)) { _ in
            actions = QuickActionType.enabled
        }
        .animation(PepBoxAnimation.state, value: items.count)
    }
    
}

// MARK: - Shelf Quick Action Button

struct ShelfQuickActionButton: View {
    let actionType: QuickActionType
    var useTransparent: Bool = false
    let shareAction: ([URL]) -> Void
    
    @State private var isHovering = false
    @State private var isTargeted = false
    
    private let size: CGFloat = 32
    
    // Border opacity matches basket style
    private var borderOpacity: Double {
        if isTargeted { return 0.3 }
        if isHovering { return 0.2 }
        return useTransparent ? 0.12 : 0.06
    }
    
    var body: some View {
        // Use AppKit-based drop target for reliable Photos.app file promise support
        FilePromiseDropTarget(isTargeted: $isTargeted, onFilesReceived: { urls in
            shareAction(urls)
        }) {
            Circle()
                // Transparent mode: use material, Dark mode: pure black
                .fill(useTransparent ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(
                            useTransparent
                                ? AdaptiveColors.overlayAuto(borderOpacity)
                                : Color.white.opacity(borderOpacity),
                            lineWidth: 1
                        )
                )
                .overlay(
                    Image(systemName: actionType.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            useTransparent
                                ? AdaptiveColors.primaryTextAuto.opacity(0.88)
                                : .white.opacity(0.85)
                        )
                )
                .scaleEffect(isTargeted ? 1.18 : (isHovering ? 1.05 : 1.0))
                .animation(PepBoxAnimation.hoverBouncy, value: isTargeted)
                .animation(PepBoxAnimation.hoverBouncy, value: isHovering)
        }
        .onHover { hovering in
            isHovering = hovering
            // Update shared state for shelf explanation overlay
            if hovering {
                PepBoxState.shared.hoveredShelfQuickAction = actionType
            } else if PepBoxState.shared.hoveredShelfQuickAction == actionType {
                PepBoxState.shared.hoveredShelfQuickAction = nil
            }
        }
        .frame(width: size, height: size)
        // Update shared state when this button is targeted
        .onChange(of: isTargeted) { _, targeted in
            if targeted {
                PepBoxState.shared.isShelfQuickActionsTargeted = true
                PepBoxState.shared.hoveredShelfQuickAction = actionType
            } else {
                // Clear hover state when drag leaves this button
                if PepBoxState.shared.hoveredShelfQuickAction == actionType {
                    PepBoxState.shared.hoveredShelfQuickAction = nil
                }
            }
        }
        // Clear hover state when button disappears
        .onDisappear {
            if PepBoxState.shared.hoveredShelfQuickAction == actionType {
                PepBoxState.shared.hoveredShelfQuickAction = nil
            }
        }
        .onTapGesture {
            let urls = PepBoxState.shared.items.map(\.url)
            if !urls.isEmpty {
                HapticFeedback.select()
                shareAction(urls)
            }
        }
    }
}
