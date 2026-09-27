//
//  CameraManager.swift
//  PepBox
//
//  Manages camera capture session lifecycle for Notchface shelf previews.
//

import SwiftUI
import Combine
@preconcurrency import AVFoundation

nonisolated final class CameraSessionBox: @unchecked Sendable {
    let session = AVCaptureSession()
}

@MainActor
final class CameraManager: ObservableObject {
    static let shared = CameraManager()
    nonisolated let objectWillChange = ObservableObjectPublisher()

    @Published var isRunning: Bool = false
    @Published var permissionStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var videoAspectRatio: CGFloat = 16.0 / 9.0

    @AppStorage(AppPreferenceKey.cameraInstalled) var isInstalled: Bool = PreferenceDefault.cameraInstalled
    @AppStorage(AppPreferenceKey.cameraEnabled) var isEnabled: Bool = PreferenceDefault.cameraEnabled

    nonisolated let sessionBox = CameraSessionBox()
    nonisolated let sessionQueue = DispatchQueue(label: "com.pepbox.camera.session")

    nonisolated var session: AVCaptureSession {
        sessionBox.session
    }

    private var isConfigured = false
    private var isStarting = false
    private var activePreviewCount = 0

    private init() {}

    // MARK: - Public API

    func previewDidAppear() {
        activePreviewCount += 1
        startSessionIfNeeded()
    }

    func previewDidDisappear() {
        activePreviewCount = max(0, activePreviewCount - 1)
        if activePreviewCount == 0 {
            stopSession()
        }
    }

    func requestAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        permissionStatus = status

        if status == .authorized {
            startSessionIfNeeded()
            return
        }

        guard status == .notDetermined else { return }

        AVCaptureDevice.requestAccess(for: .video) { granted in
            Task { @MainActor in
                let manager = CameraManager.shared
                manager.permissionStatus = granted ? .authorized : .denied
                if granted {
                    manager.startSessionIfNeeded()
                }
            }
        }
    }

    func cleanup() {
        isInstalled = false
        isEnabled = PreferenceDefault.cameraEnabled
        activePreviewCount = 0
        isConfigured = false
        isStarting = false
        stopSession()
        resetSession()
    }

    // MARK: - Internal

    private func startSessionIfNeeded() {
        guard isInstalled && isEnabled else {
            stopSession()
            return
        }

        guard activePreviewCount > 0 else { return }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        permissionStatus = status

        switch status {
        case .authorized:
            configureSessionIfNeeded()
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    let manager = CameraManager.shared
                    manager.permissionStatus = granted ? .authorized : .denied
                    if granted {
                        manager.startSessionIfNeeded()
                    }
                }
            }
        case .denied, .restricted:
            stopSession()
        @unknown default:
            stopSession()
        }
    }

    private func configureSessionIfNeeded() {
        guard !isConfigured else { return }

        var aspectRatio: CGFloat?
        let localBox = sessionBox

        sessionQueue.sync {
            let session = localBox.session
            session.beginConfiguration()
            session.sessionPreset = .high

            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video)

            guard let camera = device else {
                session.commitConfiguration()
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if session.canAddInput(input) {
                    session.addInput(input)
                }

                let format = camera.activeFormat.formatDescription
                let dimensions = CMVideoFormatDescriptionGetDimensions(format)
                if dimensions.height > 0 {
                    aspectRatio = CGFloat(dimensions.width) / CGFloat(dimensions.height)
                }
            } catch {
                session.commitConfiguration()
                return
            }

            session.commitConfiguration()
        }

        if let aspectRatio {
            videoAspectRatio = aspectRatio
        }

        isConfigured = true
    }

    private func startSession() {
        if isRunning || isStarting { return }
        isStarting = true

        let localBox = sessionBox
        sessionQueue.async {
            let session = localBox.session
            if !session.isRunning {
                session.startRunning()
            }

            Task { @MainActor in
                let manager = CameraManager.shared
                manager.isRunning = true
                manager.isStarting = false
            }
        }
    }

    private func stopSession() {
        isStarting = false

        let localBox = sessionBox
        sessionQueue.async {
            let session = localBox.session
            if session.isRunning {
                session.stopRunning()
            }

            Task { @MainActor in
                let manager = CameraManager.shared
                manager.isRunning = false
                manager.isStarting = false
            }
        }
    }

    private func resetSession() {
        let localBox = sessionBox
        sessionQueue.async {
            let session = localBox.session
            session.beginConfiguration()
            for input in session.inputs {
                session.removeInput(input)
            }
            for output in session.outputs {
                session.removeOutput(output)
            }
            session.commitConfiguration()
        }
    }
}
