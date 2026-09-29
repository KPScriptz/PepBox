//
//  ScreenshotWatcher.swift
//  PepBox
//
//  Adds new macOS screenshots and screen recordings to the shelf as they are saved.
//

import Foundation

/// Watches Spotlight for new screen captures and adds them to the shelf.
/// Uses kMDItemIsScreenCapture, so it follows the user's screenshot location and naming
/// without reading com.apple.screencapture.
final class ScreenshotWatcher: NSObject {
    static let shared = ScreenshotWatcher()

    private var query: NSMetadataQuery?
    /// Paths already added, so Spotlight re-reporting an item doesn't add it twice.
    private var addedPaths = Set<String>()
    /// Watching only for one screenshot (Ring's Screenshot action) while the setting is off.
    private var oneShotUntil: Date?

    private var isSettingEnabled: Bool {
        UserDefaults.standard.preference(AppPreferenceKey.autoAddScreenshots, default: PreferenceDefault.autoAddScreenshots)
    }

    /// Puts the next screenshot taken in the next minute on the shelf, even with the setting off.
    func captureNext() {
        oneShotUntil = Date().addingTimeInterval(60)
        start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 61) { [weak self] in
            guard let self, let until = self.oneShotUntil, until <= Date() else { return }
            self.oneShotUntil = nil
            if !self.isSettingEnabled { self.stop() }
        }
    }

    /// Starts or stops watching to match the "Add new screenshots" setting.
    func updateFromPreferences() {
        if isSettingEnabled {
            start()
        } else if oneShotUntil == nil {
            stop()
        }
    }

    private func start() {
        guard query == nil else { return }

        let query = NSMetadataQuery()
        // Only captures created from now on; existing screenshots stay where they are.
        query.predicate = NSPredicate(
            format: "kMDItemIsScreenCapture == 1 AND kMDItemFSCreationDate >= %@",
            Date() as NSDate
        )
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )
        query.start()
        self.query = query
        print("📸 ScreenshotWatcher: Watching for new screenshots")
    }

    private func stop() {
        guard let query else { return }
        query.stop()
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: query)
        self.query = nil
        addedPaths.removeAll()
        print("📸 ScreenshotWatcher: Stopped")
    }

    @objc private func queryDidUpdate(_ notification: Notification) {
        guard let added = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] else { return }

        let urls = added
            .compactMap { $0.value(forAttribute: NSMetadataItemPathKey) as? String }
            .filter { addedPaths.insert($0).inserted }
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !urls.isEmpty else { return }

        print("📸 ScreenshotWatcher: Adding \(urls.count) new screenshot(s) to shelf")
        if oneShotUntil != nil {
            oneShotUntil = nil
            if !isSettingEnabled { stop() }
        }
        DispatchQueue.main.async {
            PepBoxState.shared.addItems(from: urls)
        }
    }
}
