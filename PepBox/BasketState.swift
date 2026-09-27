// Per-basket state for multi-basket support
// Each FloatingBasketWindowController creates its own BasketState instance

import SwiftUI
import Observation

/// Per-basket state that allows multiple baskets to operate independently
/// Each basket controller creates its own BasketState, breaking the dependency on PepBoxState.shared
@Observable
final class BasketState {
    /// Owning basket window controller for this state (weak to avoid retain cycles).
    weak var ownerController: FloatingBasketWindowController?

    /// Items in this basket (regular files)
    var itemsList: [DroppedItem] = []
    
    /// Power Folders in this basket (pinned directories)
    var powerFolders: [DroppedItem] = []
    
    /// All items (computed property for convenience)
    var items: [DroppedItem] {
        get { itemsList + powerFolders }
        set {
            itemsList = newValue.filter { !($0.isPinned && $0.isDirectory) }
            powerFolders = newValue.filter { $0.isPinned && $0.isDirectory }
        }
    }
    
    /// Currently selected items in this basket
    var selectedItems: Set<UUID> = []
    
    /// Whether files are being hovered over this basket
    var isTargeted: Bool = false
    
    /// Whether files are being hovered over AirDrop zone in this basket
    var isAirDropZoneTargeted: Bool = false
    
    /// Whether files are being hovered over quick action buttons in this basket
    var isQuickActionsTargeted: Bool = false
    
    /// Which quick action is currently hovered (if any)
    var hoveredQuickAction: QuickActionType? = nil
    
    /// Flag for bulk operations (disable animations)
    var isBulkUpdating: Bool = false
    
    /// Items showing poof animation
    var poofingItemIds: Set<UUID> = []
    
    /// Items being processed (showing spinner)
    var processingItemIds: Set<UUID> = []
    
    /// Current Quick Share status
    var quickShareStatus: QuickShareStatus = .idle
    
    /// Whether rename is active (blocks Quick Look)
    var isRenaming: Bool = false

    /// Anchor item for shift-range selection.
    var lastSelectionAnchor: UUID?
    
    // MARK: - Item Management
    
    /// Adds an item to this basket
    func addItem(_ item: DroppedItem) {
        let enablePowerFolders = UserDefaults.standard.object(forKey: AppPreferenceKey.enablePowerFolders) as? Bool ?? true
        if item.isDirectory && enablePowerFolders {
            guard !powerFolders.contains(where: { $0.url == item.url }) else { return }
            powerFolders.append(item)
        } else {
            guard !itemsList.contains(where: { $0.url == item.url }) else { return }
            itemsList.append(item)
        }
        HapticFeedback.drop()
    }
    
    /// Adds multiple items from URLs
    func addItems(from urls: [URL]) {
        guard !urls.isEmpty else { return }
        
        let isBulk = urls.count > 3
        if isBulk { isBulkUpdating = true }
        
        let enablePowerFolders = UserDefaults.standard.object(forKey: AppPreferenceKey.enablePowerFolders) as? Bool ?? true
        let existingURLs = Set(itemsList.map(\.url) + powerFolders.map(\.url))
        
        for url in urls where !existingURLs.contains(url) {
            let item = DroppedItem(url: url)
            if item.isDirectory && enablePowerFolders {
                powerFolders.append(item)
            } else {
                itemsList.append(item)
            }
        }
        
        HapticFeedback.drop()
        
        if isBulk {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.isBulkUpdating = false
            }
        }
    }
    
    /// Removes an item from this basket
    func removeItem(_ item: DroppedItem) {
        item.cleanupIfTemporary()
        powerFolders.removeAll { $0.id == item.id }
        itemsList.removeAll { $0.id == item.id }
        selectedItems.remove(item.id)
        HapticFeedback.delete()
    }
    
    /// Removes an item without cleanup (for transfers)
    func removeItemForTransfer(_ item: DroppedItem) {
        powerFolders.removeAll { $0.id == item.id }
        itemsList.removeAll { $0.id == item.id }
        selectedItems.remove(item.id)
    }
    
    /// Clears all items (preserves pinned folders)
    func clearAll() {
        for item in itemsList { item.cleanupIfTemporary() }
        itemsList.removeAll()
        
        let unpinned = powerFolders.filter { !$0.isPinned }
        for item in unpinned { item.cleanupIfTemporary() }
        powerFolders.removeAll { !$0.isPinned }
        
        selectedItems.removeAll()
    }
    
    /// Replaces an item with a new one (for conversions)
    func replaceItem(_ oldItem: DroppedItem, with newItem: DroppedItem) {
        if let index = items.firstIndex(where: { $0.id == oldItem.id }) {
            items[index] = newItem
            if selectedItems.contains(oldItem.id) {
                selectedItems.remove(oldItem.id)
                selectedItems.insert(newItem.id)
            }
        }
    }
    
    /// Replaces multiple items with one (for ZIP)
    func replaceItems(_ oldItems: [DroppedItem], with newItem: DroppedItem) {
        let idsToRemove = Set(oldItems.map(\.id))
        var newList = items.filter { !idsToRemove.contains($0.id) }
        newList.append(newItem)
        items = newList
        selectedItems.subtract(idsToRemove)
        selectedItems.insert(newItem.id)
    }
    
    /// Validates items still exist on disk
    func validateItems() {
        let fm = FileManager.default
        let ghosts = items.filter { !fm.fileExists(atPath: $0.url.path) }
        for item in ghosts {
            removeItem(item)
        }
    }
    
    // MARK: - Animation Helpers
    
    func triggerPoof(for id: UUID) { poofingItemIds.insert(id) }
    func clearPoof(for id: UUID) { poofingItemIds.remove(id) }
    func beginProcessing(for id: UUID) { processingItemIds.insert(id) }
    func endProcessing(for id: UUID) { processingItemIds.remove(id) }

    // MARK: - Compatibility API (BasketItemView Migration)

    /// Backward-compat alias used by existing basket item components.
    var basketItems: [DroppedItem] { items }

    /// Backward-compat alias used by existing basket item components.
    var selectedBasketItems: Set<UUID> {
        get { selectedItems }
        set { selectedItems = newValue }
    }

    /// Proxy interaction-blocked state (global UI lock).
    var isInteractionBlocked: Bool {
        get { PepBoxState.shared.isInteractionBlocked }
        set { PepBoxState.shared.isInteractionBlocked = newValue }
    }

    func beginFileOperation() {
        PepBoxState.shared.beginFileOperation()
    }

    func endFileOperation() {
        PepBoxState.shared.endFileOperation()
    }

    func removeBasketItem(_ item: DroppedItem) {
        removeItem(item)
    }

    func removeBasketItemForTransfer(_ item: DroppedItem) {
        removeItemForTransfer(item)
    }

    func replaceBasketItem(_ oldItem: DroppedItem, with newItem: DroppedItem) {
        replaceItem(oldItem, with: newItem)
    }

    func replaceBasketItems(_ oldItems: [DroppedItem], with newItem: DroppedItem) {
        replaceItems(oldItems, with: newItem)
    }

    func toggleBasketSelection(_ item: DroppedItem) {
        lastSelectionAnchor = item.id
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    func selectBasket(_ item: DroppedItem) {
        lastSelectionAnchor = item.id
        selectedItems = [item.id]
    }

    func selectBasketRange(to item: DroppedItem) {
        guard let anchorId = lastSelectionAnchor,
              let anchorIndex = items.firstIndex(where: { $0.id == anchorId }),
              let targetIndex = items.firstIndex(where: { $0.id == item.id }) else {
            selectBasket(item)
            return
        }

        let start = min(anchorIndex, targetIndex)
        let end = max(anchorIndex, targetIndex)
        let rangeIds = items[start...end].map(\.id)
        selectedItems.formUnion(rangeIds)
    }

    func deselectAllBasket() {
        selectedItems.removeAll()
        lastSelectionAnchor = nil
    }

    func togglePin(_ item: DroppedItem) {
        if let index = itemsList.firstIndex(where: { $0.id == item.id }) {
            itemsList[index].isPinned.toggle()
            HapticFeedback.pin()
            persistPinnedFolders()
            return
        }
        if let index = powerFolders.firstIndex(where: { $0.id == item.id }) {
            powerFolders[index].isPinned.toggle()
            HapticFeedback.pin()
            persistPinnedFolders()
        }
    }

    private func persistPinnedFolders() {
        let currentPinned = Set((PepBoxState.shared.items + items).filter(\.isPinned).map { $0.url.absoluteString })
        UserDefaults.standard.set(Array(currentPinned), forKey: "pinnedFolderURLs")
    }
}
