import AVFoundation
import SwiftUI
import UIKit
import Vision

final class NoseCameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum Mode { case noseBridge, facePresence }
    struct FaceSample { let visible: Bool; let uptime: TimeInterval }
    private let mode: Mode
    @Published private(set) var faceSample: FaceSample?

    init(mode: Mode = .noseBridge) { self.mode = mode; super.init() }

    enum Status: Equatable {
        case requestingPermission, starting, lookingForNose, tracking, denied, unavailable, failed
    }
    @Published private(set) var status: Status = .starting
    @Published private(set) var noseLevel: CGFloat?
    let session = AVCaptureSession()

    // Configuration, frame processing and shutdown share one serial queue.
    private let cameraQueue = DispatchQueue(label: "com.dash1971.focusapp.nose-camera")
    private let intentLock = NSLock()
    private var runID: UUID?
    private var configured = false
    private var filter = NoseTrackingFilter()

    func start() {
        intentLock.lock()
        guard runID == nil else { intentLock.unlock(); return }
        let id = UUID()
        runID = id
        intentLock.unlock()
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configureAndStart(id)
        case .notDetermined:
            status = .requestingPermission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self, self.isCurrent(id) else { return }
                    if granted { self.configureAndStart(id) }
                    else { self.status = .denied }
                }
            }
        case .denied, .restricted: status = .denied
        @unknown default: status = .failed
        }
    }

    func stop() {
        intentLock.lock(); runID = nil; intentLock.unlock()
        noseLevel = nil
        faceSample = nil
        cameraQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            self.filter = NoseTrackingFilter()
        }
    }

    private func isCurrent(_ id: UUID) -> Bool {
        intentLock.lock(); defer { intentLock.unlock() }
        return runID == id
    }

    private func configureAndStart(_ id: UUID) {
        status = .starting
        cameraQueue.async { [weak self] in
            guard let self, self.isCurrent(id) else { return }
            if !self.configured, !self.configureSession(id) { return }
            guard self.isCurrent(id) else { return }
            self.filter = NoseTrackingFilter()
            if !self.session.isRunning { self.session.startRunning() }
            self.publish(nil, status: .lookingForNose, id: id)
        }
    }

    private func configureSession(_ id: UUID) -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        // A failed attempt must not leave a partial input/output on retry.
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        session.sessionPreset = session.canSetSessionPreset(.hd1280x720) ? .hd1280x720 : .high
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            publish(nil, status: .unavailable, id: id); return false
        }
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard session.canAddInput(input) else { publish(nil, status: .failed, id: id); return false }
            session.addInput(input)
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: cameraQueue)
            guard session.canAddOutput(output) else { publish(nil, status: .failed, id: id); return false }
            session.addOutput(output)
            // Rotate/mirror the pixel buffer and preview identically. Vision
            // then receives upright pixels, avoiding the old orientation guess.
            if let connection = output.connection(with: .video) { configurePortrait(connection) }
            try camera.lockForConfiguration()
            if camera.isExposureModeSupported(.continuousAutoExposure) { camera.exposureMode = .continuousAutoExposure }
            if camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { camera.whiteBalanceMode = .continuousAutoWhiteBalance }
            camera.unlockForConfiguration()
            configured = true
            return true
        } catch { publish(nil, status: .failed, id: id); return false }
    }

    private func publish(_ level: Double?, status: Status, id: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isCurrent(id) else { return }
            self.noseLevel = level.map { CGFloat($0) }
            self.status = status
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        intentLock.lock(); let id = runID; intentLock.unlock()
        guard let id else { return }
        let now = ProcessInfo.processInfo.systemUptime
        // Unlocking deliberately uses bounding boxes only: no eye landmarks,
        // pupil positions, gaze direction, identity recognition or recording.
        if mode == .facePresence {
            let request = VNDetectFaceRectanglesRequest()
            var visible = false
            do {
                try VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:]).perform([request])
                visible = request.results?.contains { $0.confidence >= 0.7 } == true
            } catch { visible = false }
            let detected = visible
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isCurrent(id) else { return }
                self.faceSample = FaceSample(visible: detected, uptime: now)
                self.status = detected ? .tracking : .lookingForNose
            }
            return
        }
        let request = VNDetectFaceLandmarksRequest()
        var measurement: Double?
        do {
            try VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:]).perform([request])
            if let face = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }),
               let crest = face.landmarks?.noseCrest, !crest.normalizedPoints.isEmpty {
                // Use the top of the nose crest (bridge/inner-eye height), not
                // the nose tip, eye contours, pupils or gaze displacement.
                let bridge = crest.normalizedPoints.max(by: { $0.y < $1.y })!
                let frameY = face.boundingBox.minY + bridge.y * face.boundingBox.height
                measurement = NoseTrackingPolicy.screenLevel(bridgeY: Double(frameY))
            }
        } catch { measurement = nil }
        let level = filter.update(measurement, at: now)
        publish(level, status: level == nil ? .lookingForNose : .tracking, id: id)
    }
}

private func configurePortrait(_ connection: AVCaptureConnection) {
    connection.automaticallyAdjustsVideoMirroring = false
    if connection.isVideoMirroringSupported { connection.isVideoMirrored = true }
    if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
}

struct NoseCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ view: PreviewView, context: Context) { view.previewLayer.session = session }
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        override func layoutSubviews() {
            super.layoutSubviews()
            if let connection = previewLayer.connection { configurePortrait(connection) }
        }
    }
}
