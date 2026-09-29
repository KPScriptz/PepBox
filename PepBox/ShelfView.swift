//
//  ShelfView.swift
//  PepBox
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI

/// The main shelf view that displays dropped items and handles new drops
/// Items display as individual tiles (stacks feature removed)
struct ShelfView: View {
    /// Reference to the app state
    @Bindable var state: PepBoxState
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    
    /// Whether the shelf has any content (items or power folders)
    private var hasContent: Bool {
        !state.shelfItems.isEmpty || !state.shelfPowerFolders.isEmpty
    }
    
    var body: some View {
        ZStack {
            if hasContent {
                itemsScrollView
            } else {
                emptyStateView
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard hasContent else { return }
            state.deselectAll()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pepboxSurface(transparent: useTransparentBackground)
        .dropDestination(for: URL.self) { urls, _ in
            withAnimation(PepBoxAnimation.transition) {
                state.addItems(from: urls)
            }
            return true
        }
    }
    
    // MARK: - Items Scroll View
    
    private var itemsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                // Power Folders first
                ForEach(state.shelfPowerFolders) { folder in
                    DroppedItemView(
                        item: folder,
                        isSelected: state.selectedItems.contains(folder.id),
                        onSelect: {
                            withAnimation(PepBoxAnimation.state) {
                                state.toggleSelection(folder)
                            }
                        },
                        onRemove: {
                            withAnimation(PepBoxAnimation.state) {
                                state.shelfPowerFolders.removeAll { $0.id == folder.id }
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Regular items
                ForEach(state.shelfItems) { item in
                    DroppedItemView(
                        item: item,
                        isSelected: state.selectedItems.contains(item.id),
                        onSelect: {
                            withAnimation(PepBoxAnimation.state) {
                                state.toggleSelection(item)
                            }
                        },
                        onRemove: {
                            withAnimation(PepBoxAnimation.state) {
                                state.removeItem(item)
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .compositingGroup()
        }
        .animation(PepBoxAnimation.transition, value: state.shelfItems.count)
        .animation(PepBoxAnimation.transition, value: state.shelfPowerFolders.count)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: PepBoxRadius.xxl + 2, style: .continuous)
                    .fill(Color(NSColor.labelColor).opacity(0.05))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("Shelf is empty")
                    .font(.system(size: 13, weight: .semibold))
                
                Text("Drop files or folders here")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ShelfView(state: PepBoxState.shared)
        .frame(width: 400, height: 150)
}
