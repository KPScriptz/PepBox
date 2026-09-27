//
//  TemporaryFileStorageService.swift
//  PepBox
//
//  Handles temporary file creation and cleanup for drag-and-drop operations

import Foundation
import AppKit

/// Types of temporary files that can be created
enum TempFileType {
    case data(Data, suggestedName: String?)
    case text(String)
    case url(URL)
    case namedWeblocURL(URL, name: String) // For emails with a subject line
}

/// Service for managing temporary file lifecycle
/// Ensures temp files are properly cleaned up when items are removed from the shelf/basket
class TemporaryFileStorageService {
    static let shared = TemporaryFileStorageService()
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Creates a temporary file and tracks it for manual cleanup
    func createTempFile(for type: TempFileType) async -> URL? {
        return await withCheckedContinuation { continuation in
            let result = createTempFileSync(for: type)
            continuation.resume(returning: result)
        }
    }
    
    /// Removes temporary file and its containing folder if empty
    /// Only deletes files within NSTemporaryDirectory() for safety
    func removeTemporaryFileIfNeeded(at url: URL) {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        
        // Safety check: Only delete files within temp directory
        guard url.path.hasPrefix(tempDirectory.path) else {
            print("⚠️ TemporaryFileStorageService: Attempted to remove file outside temp directory: \(url.path)")
            return
        }
        
        let folderURL = url.deletingLastPathComponent()
        
        do {
            // Delete the file
            try FileManager.default.removeItem(at: url)
            print("✅ TemporaryFileStorageService: Deleted file: \(url.lastPathComponent)")
            
            // Check if parent folder is empty and delete it
            let contents = try FileManager.default.contentsOfDirectory(atPath: folderURL.path)
            if contents.isEmpty {
                try FileManager.default.removeItem(at: folderURL)
                print("🗑️ TemporaryFileStorageService: Folder was empty, deleted: \(folderURL.lastPathComponent)")
            } else {
                print("📂 TemporaryFileStorageService: Folder not deleted — contains \(contents.count) item(s)")
            }
        } catch {
            print("❌ TemporaryFileStorageService: Error during cleanup: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Implementation
    
    private func createTempFileSync(for type: TempFileType) -> URL? {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let uuid = UUID().uuidString
        
        switch type {
        case .data(let data, let suggestedName):
            let filename = suggestedName ?? "file.dat"
            let dirURL = tempDir.appendingPathComponent(uuid, isDirectory: true)
            let fileURL = dirURL.appendingPathComponent(filename)
            
            do {
                try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
                try data.write(to: fileURL)
                print("✅ TemporaryFileStorageService: Created temp file: \(filename)")
                return fileURL
            } catch {
                print("❌ TemporaryFileStorageService: Failed to create temp file: \(error)")
                return nil
            }
            
        case .text(let string):
            let filename = "\(uuid).txt"
            let dirURL = tempDir.appendingPathComponent(uuid, isDirectory: true)
            let fileURL = dirURL.appendingPathComponent(filename)
            
            guard let data = string.data(using: .utf8) else {
                print("❌ TemporaryFileStorageService: Failed to convert text to data")
                return nil
            }
            
            do {
                try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
                try data.write(to: fileURL)
                print("✅ TemporaryFileStorageService: Created temp text file")
                return fileURL
            } catch {
                print("❌ TemporaryFileStorageService: Failed to create temp text file: \(error)")
                return nil
            }
            
        case .url(let url):
            let filename = "\(url.host ?? uuid).webloc"
            let dirURL = tempDir.appendingPathComponent(uuid, isDirectory: true)
            let fileURL = dirURL.appendingPathComponent(filename)
            
            let weblocContent = createWeblocContent(for: url)
            guard let data = weblocContent.data(using: .utf8) else {
                print("❌ TemporaryFileStorageService: Failed to create webloc data")
                return nil
            }
            
            do {
                try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
                try data.write(to: fileURL)
                print("✅ TemporaryFileStorageService: Created temp webloc file")
                return fileURL
            } catch {
                print("❌ TemporaryFileStorageService: Failed to create temp webloc file: \(error)")
                return nil
            }
            
        case .namedWeblocURL(let url, let name):
            // Sanitize the name for use as a filename
            let sanitizedName = name
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: "\\", with: "-")
                .trimmingCharacters(in: .whitespaces)
            let filename = "\(String(sanitizedName.prefix(100))).webloc"
            let dirURL = tempDir.appendingPathComponent(uuid, isDirectory: true)
            let fileURL = dirURL.appendingPathComponent(filename)
            
            let weblocContent = createWeblocContent(for: url)
            guard let data = weblocContent.data(using: .utf8) else {
                print("❌ TemporaryFileStorageService: Failed to create named webloc data")
                return nil
            }
            
            do {
                try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
                try data.write(to: fileURL)
                print("✅ TemporaryFileStorageService: Created temp named webloc file: \(filename)")
                return fileURL
            } catch {
                print("❌ TemporaryFileStorageService: Failed to create temp named webloc file: \(error)")
                return nil
            }
        }
    }
    
    private func createWeblocContent(for url: URL) -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>URL</key>
            <string>\(url.absoluteString)</string>
        </dict>
        </plist>
        """
    }
}
