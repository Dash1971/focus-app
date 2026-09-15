import AVFoundation
import SwiftUI
import UIKit
import Vision

final class EyeLevelCameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum Status: Equatable {
        case requestingPermission
        case starting
        case lookingForEyes
        case tracking
        case denied
        case unavailable
        case failed
    }

    @Published private(set) var status: Status = .starting
    @Published private(set) var eyeLevel: CGFloat?

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.dash1971.focusapp.eye-camera")
    private let visionQueue = DispatchQueue(label: "com.dash1971.focusapp.eye-vision")
    private var configured = false
    private var running = false
    private var missingEyeFrames = 0

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            status = .requestingPermission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted { self.configureAndStart() }
                    else { self.status = .denied }
                }
            }
        case .denied, .restricted:
            status = .denied
        @unknown default:
            status = .failed
        }
    }

    func stop() {
        running = false
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configureAndStart() {
        status = .starting
        running = true
        sessionQueue.async { [weak self] in
            guard let self, self.running else { return }
            if !self.configured, !self.configureSession() { return }
            guard self.running else { return }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async {
                if self.running { self.status = .lookingForEyes }
            }
        }
    }

    private func configureSession() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .medium

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        )
        guard let camera = discovery.devices.first else {
            updateFailure(.unavailable)
            return false
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard session.canAddInput(input) else {
                updateFailure(.failed)
                return false
            }
            session.addInput(input)
        } catch {
            updateFailure(.failed)
            return false
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: visionQueue)
        guard session.canAddOutput(output) else {
            updateFailure(.failed)
            return false
        }
        session.addOutput(output)
        configured = true
        return true
    }

    private func updateFailure(_ value: Status) {
        DispatchQueue.main.async { [weak self] in self?.status = value }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard running else { return }
        let request = VNDetectFaceLandmarksRequest { [weak self] request, _ in
            guard let self else { return }
            let faces = (request.results as? [VNFaceObservation]) ?? []
            guard let face = faces.max(by: { $0.boundingBox.width < $1.boundingBox.width }),
                  let landmarks = face.landmarks else {
                self.noteMissingEyes()
                return
            }

            let eyeRegions = [landmarks.leftEye, landmarks.rightEye].compactMap { $0 }
            let points = eyeRegions.flatMap { Array($0.normalizedPoints) }
            guard !points.isEmpty else {
                self.noteMissingEyes()
                return
            }

            self.missingEyeFrames = 0
            let localY = points.reduce(CGFloat.zero) { $0 + $1.y } / CGFloat(points.count)
            let imageY = face.boundingBox.minY + localY * face.boundingBox.height
            let topOriginEyeLevel = min(1, max(0, 1 - imageY))
            DispatchQueue.main.async {
                guard self.running else { return }
                let previous = self.eyeLevel ?? topOriginEyeLevel
                self.eyeLevel = previous * 0.72 + topOriginEyeLevel * 0.28
                self.status = .tracking
            }
        }

        try? VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .leftMirrored,
            options: [:]
        ).perform([request])
    }

    private func noteMissingEyes() {
        missingEyeFrames += 1
        guard missingEyeFrames >= 5 else { return }
        DispatchQueue.main.async {
            if self.running {
                self.eyeLevel = nil
                self.status = .lookingForEyes
            }
        }
    }
}

struct EyeCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.previewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let connection = previewLayer.connection else { return }
            connection.automaticallyAdjustsVideoMirroring = false
            if connection.isVideoMirroringSupported { connection.isVideoMirrored = true }
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
        }
    }
}
