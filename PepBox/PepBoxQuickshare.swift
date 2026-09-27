//
//  PepBoxQuickshare.swift
//  PepBox
//
//  Shared Quickshare logic for uploading files and getting shareable links
//  Can be called from context menus, quick action buttons, etc.
//

import Foundation
import AppKit

/// PepBox Quickshare - uploads files to 0x0.st and gets shareable links
enum PepBoxQuickshare {
    
    /// Share files via PepBox Quickshare
    /// Multiple files are automatically zipped into a single archive
    static func share(urls: [URL], completion: (() -> Void)? = nil) {
        guard !ExtensionType.quickshare.isRemoved else { return }
        guard !urls.isEmpty else { return }
        guard !PepBoxState.shared.isSharingInProgress else { return }
        
        PepBoxState.shared.isSharingInProgress = true
        PepBoxState.shared.quickShareStatus = .uploading
        
        // Determine display filename for progress window
        let displayFilename: String
        if urls.count > 1 {
            displayFilename = "PepBox Share (\(urls.count) items).zip"
        } else {
            guard let firstURL = urls.first else { return }
            displayFilename = firstURL.lastPathComponent
        }
        
        // Show progress window IMMEDIATELY so user knows upload is in progress
        DispatchQueue.main.async {
            QuickShareSuccessWindowController.showUploading(filename: displayFilename, fileCount: urls.count)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard var uploadURL = urls.first else { return }
            var isTemporaryZip = false
            var finalDisplayFilename = displayFilename
            
            // If multiple files, create a ZIP first
            if urls.count > 1 {
                guard let zipURL = createZIP(from: urls) else {
                    DispatchQueue.main.async {
                        PepBoxState.shared.isSharingInProgress = false
                        PepBoxState.shared.quickShareStatus = .failed
                        QuickShareSuccessWindowController.updateToFailed(error: "Failed to create archive")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            PepBoxState.shared.quickShareStatus = .idle
                        }
                    }
                    return
                }
                uploadURL = zipURL
                isTemporaryZip = true
                finalDisplayFilename = "PepBox Share (\(urls.count) items).zip"
            }
            
            // Upload the file
            let result = uploadTo0x0(fileURL: uploadURL)
            
            // Generate thumbnail from original file(s) before cleanup
            let thumbnailData: Data? = urls.first.flatMap { QuickshareItem.generateThumbnail(from: $0) }
            let itemCount = urls.count
            
            // Clean up temporary zip if we created one
            if isTemporaryZip {
                try? FileManager.default.removeItem(at: uploadURL)
            }
            
            DispatchQueue.main.async {
                PepBoxState.shared.isSharingInProgress = false
                
                if let result = result {
                    // Success! Copy URL to clipboard
                    let clipboard = NSPasteboard.general
                    clipboard.clearContents()
                    clipboard.setString(result.shareURL, forType: .string)
                    
                    // Store in Quickshare Manager for history
                    let quickshareItem = QuickshareItem(
                        filename: finalDisplayFilename,
                        shareURL: result.shareURL,
                        token: result.token,
                        fileSize: result.fileSize,
                        thumbnailData: thumbnailData,
                        itemCount: itemCount
                    )
                    print("🚀 [PepBoxQuickshare] Created item, calling addItem...")
                    QuickshareManager.shared.addItem(quickshareItem)
                    print("🚀 [PepBoxQuickshare] addItem called, manager items: \(QuickshareManager.shared.items.count)")
                    
                    // Show success feedback
                    PepBoxState.shared.quickShareStatus = .success(urls: [result.shareURL])
                    HapticFeedback.copy()
                    
                    // Update window to success state (transitions smoothly)
                    QuickShareSuccessWindowController.updateToSuccess(shareURL: result.shareURL)
                    
                    // Call completion handler (e.g. to hide basket)
                    completion?()
                    
                    // Reset status after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        PepBoxState.shared.quickShareStatus = .idle
                    }
                } else {
                    // Upload failed
                    PepBoxState.shared.quickShareStatus = .failed
                    QuickShareSuccessWindowController.updateToFailed(error: "Upload failed. Please try again.")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        PepBoxState.shared.quickShareStatus = .idle
                    }
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// Creates a ZIP archive from multiple files
    private static func createZIP(from urls: [URL]) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let zipName = "PepBox Share (\(urls.count) items).zip"
        let zipURL = tempDir.appendingPathComponent(zipName)
        
        // Remove existing zip if any
        try? FileManager.default.removeItem(at: zipURL)
        
        // Create zip using Archive utility
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = tempDir
        
        // Copy files to temp dir first for clean paths
        let stagingDir = tempDir.appendingPathComponent("pepbox_staging_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        
        var stagedFiles: [String] = []
        for url in urls {
            let destURL = stagingDir.appendingPathComponent(url.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: url, to: destURL)
                stagedFiles.append(url.lastPathComponent)
            } catch {
                print("Failed to stage file for ZIP: \(error)")
            }
        }
        
        guard !stagedFiles.isEmpty else {
            try? FileManager.default.removeItem(at: stagingDir)
            return nil
        }
        
        process.currentDirectoryURL = stagingDir
        process.arguments = ["-r", zipURL.path] + stagedFiles
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Cleanup staging
            try? FileManager.default.removeItem(at: stagingDir)
            
            if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: zipURL.path) {
                return zipURL
            }
        } catch {
            print("ZIP creation failed: \(error)")
        }
        
        try? FileManager.default.removeItem(at: stagingDir)
        return nil
    }
    
    /// Upload result containing URL and management token
    struct UploadResult {
        let shareURL: String
        let token: String
        let fileSize: Int64
    }
    
    /// Uploads a file to 0x0.st and returns the shareable URL and management token
    private static func uploadTo0x0(fileURL: URL) -> UploadResult? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: UploadResult? = nil
        
        // Get file size for expiration calculation
        let fileSize: Int64 = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        
        // Create multipart form data request
        let url = URL(string: "https://0x0.st")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("PepBox/1.0", forHTTPHeaderField: "User-Agent")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let filename = fileURL.lastPathComponent

        guard let multipartFileURL = createMultipartBodyFile(fileURL: fileURL, filename: filename, boundary: boundary) else {
            return nil
        }
        defer { try? FileManager.default.removeItem(at: multipartFileURL) }

        request.timeoutInterval = 120

        let task = URLSession.shared.uploadTask(with: request, fromFile: multipartFileURL) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("Upload error: \(error)")
                return
            }
            
            // Extract X-Token from response headers
            var token = ""
            if let httpResponse = response as? HTTPURLResponse {
                token = httpResponse.value(forHTTPHeaderField: "X-Token") ?? ""
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                let trimmed = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("http") {
                    result = UploadResult(shareURL: trimmed, token: token, fileSize: fileSize)
                }
            }
        }
        
        task.resume()
        if semaphore.wait(timeout: .now() + 180) == .timedOut {
            task.cancel()
            return nil
        }
        
        return result
    }

    /// Build multipart body as a temporary file to avoid loading large uploads fully in memory.
    private static func createMultipartBodyFile(fileURL: URL, filename: String, boundary: String) -> URL? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepbox_upload_\(UUID().uuidString).tmp")

        FileManager.default.createFile(atPath: tempURL.path, contents: nil)

        guard let outputHandle = try? FileHandle(forWritingTo: tempURL),
              let inputHandle = try? FileHandle(forReadingFrom: fileURL) else {
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }

        defer {
            outputHandle.closeFile()
            inputHandle.closeFile()
        }

        let header = """
        --\(boundary)\r
        Content-Disposition: form-data; name="file"; filename="\(filename)"\r
        Content-Type: application/octet-stream\r
        \r
        """
        outputHandle.write(Data(header.utf8))

        let chunkSize = 64 * 1024
        while true {
            let chunk = inputHandle.readData(ofLength: chunkSize)
            if chunk.isEmpty { break }
            outputHandle.write(chunk)
        }

        let footer = "\r\n--\(boundary)--\r\n"
        outputHandle.write(Data(footer.utf8))

        return tempURL
    }
}
