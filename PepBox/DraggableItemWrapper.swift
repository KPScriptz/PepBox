//
//  DraggableItemWrapper.swift
//  PepBox
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI
import AppKit

/// A wrapper view that enables multi-item dragging by intercepting mouse events
struct DraggableItemWrapper<Content: View>: NSViewRepresentable {
    let content: Content
    let items: () -> [NSItemProvider]
    var onDragComplete: (() -> Void)?
    
    init(@ViewBuilder content: () -> Content, items: @escaping () -> [NSItemProvider], onDragComplete: (() -> Void)? = nil) {
        self.content = content()
        self.items = items
        self.onDragComplete = onDragComplete
    }
    
    func makeNSView(context: Context) -> DragContainerView<Content> {
        return DragContainerView(rootView: content, items: items, onDragComplete: onDragComplete)
    }
    
    func updateNSView(_ nsView: DragContainerView<Content>, context: Context) {
        nsView.update(rootView: content, items: items, onDragComplete: onDragComplete)
    }
}

/// Custom NSView that contains the hosting view and handles drag events
class DragContainerView<Content: View>: NSView, NSDraggingSource {
    var items: () -> [NSItemProvider]
    var onDragComplete: (() -> Void)?
    private var hostingView: NSHostingView<Content>
    
    init(rootView: Content, items: @escaping () -> [NSItemProvider], onDragComplete: (() -> Void)? = nil) {
        self.items = items
        self.onDragComplete = onDragComplete
        self.hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        
        // Setup hosting view
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)
        
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Swift 6.3 (Xcode 26.6) crashes in the EarlyPerfInliner pass while optimizing the
    /// implicit deinit of this generic NSView subclass in Release builds. An explicit
    /// deinit that the optimizer skips avoids the crash; it has nothing to clean up itself.
    @_optimize(none)
    deinit {}
    
    func update(rootView: Content, items: @escaping () -> [NSItemProvider], onDragComplete: (() -> Void)?) {
        self.hostingView.rootView = rootView
        self.items = items
        self.onDragComplete = onDragComplete
    }
    
    override func mouseDragged(with event: NSEvent) {
        let pasteboardItems = items()
        guard !pasteboardItems.isEmpty else { return }
        
        // Convert NSItemProviders to NSDraggingItems
        let draggingItems = pasteboardItems.enumerated().compactMap { (index, item) -> NSDraggingItem? in
            // Ensure the item is treated as NSPasteboardWriting
            guard let writer = item as? NSPasteboardWriting else { return nil }
            let dragItem = NSDraggingItem(pasteboardWriter: writer)
            
            // Set the dragging frame
            // We use the view's bounds for the drag image source
            let dragImage = self.bitmapImageRepForCachingDisplay(in: bounds)?
                .cgImage.map { NSImage(cgImage: $0, size: bounds.size) } ?? NSImage()
            
            dragItem.setDraggingFrame(bounds, contents: dragImage)
            return dragItem
        }
        
        guard !draggingItems.isEmpty else { return }
        
        // Begin dragging session
        beginDraggingSession(with: draggingItems, event: event, source: self)
    }
    
    // MARK: - NSDraggingSource
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy // Allow copying to other apps
    }
    
    /// Called when drag session ends - detect successful external drops
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        // If operation is not .none, the drop was successful (external app accepted it)
        if operation != [] {
            print("🎯 PepBox: Drag-out completed successfully (operation: \(operation.rawValue))")
            DispatchQueue.main.async { [weak self] in
                self?.onDragComplete?()
            }
        }
    }
}
