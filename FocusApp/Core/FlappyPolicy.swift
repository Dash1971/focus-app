import Foundation

struct FlappyDifficulty {
    let activeSeconds: TimeInterval
    private var progress: Double { min(49, max(0, activeSeconds) / 20) / 49 }
    var level: Int { 1 + Int(min(49, max(0, activeSeconds) / 20)) }
    var speed: Double { 132 + 98 * progress }
    var gapHeight: Double { 158 - 38 * progress }
    var spawnInterval: Double { 1.75 - 0.55 * progress }
}

// Eye corners (not pupils/iris/gaze) define the eye-line in the camera image.
enum EyeTrackingPolicy {
    static func eyeCornerCenter(_ points: [CGPoint]) -> CGPoint? {
        guard let inner = points.min(by: { $0.x < $1.x }),
              let outer = points.max(by: { $0.x < $1.x }) else { return nil }
        return CGPoint(x: (inner.x + outer.x) / 2, y: (inner.y + outer.y) / 2)
    }

    static func screenLevel(eyeY: Double) -> Double? {
        guard eyeY.isFinite, (0...1).contains(eyeY) else { return nil }
        return 1 - eyeY
    }

    // Match AVCaptureVideoPreviewLayer.resizeAspectFill, including cropping.
    static func previewCoordinate(_ value: Double, imageWidth: Double, imageHeight: Double,
                                  viewWidth: Double, viewHeight: Double, horizontal: Bool) -> Double {
        guard imageWidth > 0, imageHeight > 0, viewWidth > 0, viewHeight > 0 else { return 0 }
        let scale = max(viewWidth / imageWidth, viewHeight / imageHeight)
        let image = horizontal ? imageWidth : imageHeight
        let view = horizontal ? viewWidth : viewHeight
        return value * image * scale - (image * scale - view) / 2
    }
}

struct EyeTrackingFilter {
    private(set) var level: Double?
    private var referencePitch: Double?
    private var referenceRoll: Double?
    private var lastValid: TimeInterval?
    private var lastUpdate: TimeInterval?

    mutating func update(_ measurement: Double?, pitch: Double? = 0, roll: Double? = 0, at time: TimeInterval) -> Double? {
        guard time.isFinite, time >= (lastUpdate ?? time) else { return level }
        guard let measurement, measurement.isFinite, (0...1).contains(measurement),
              let pitch, pitch.isFinite, let roll, roll.isFinite else {
            if let lastValid, time - lastValid <= 0.18 { return level }
            level = nil; lastUpdate = nil
            referencePitch = nil; referenceRoll = nil
            return nil
        }
        if referencePitch == nil { referencePitch = pitch; referenceRoll = roll }
        // Orientation is a veto only, never the control signal. A nod or roll
        // holds the last eye-line position instead of moving the bird. Calibrate
        // in the natural push-up posture; vertical translation remains the input.
        if abs(pitch - (referencePitch ?? pitch)) > 0.07 || abs(roll - (referenceRoll ?? roll)) > 0.10 {
            lastValid = time; lastUpdate = time
            return level
        }
        let elapsed = max(0, time - (lastUpdate ?? time))
        let alpha = 1 - exp(-elapsed / 0.12)
        if let previous = level, let lastValid, time - lastValid < 0.2 {
            let difference = abs(measurement - previous) < 0.002 ? 0 : measurement - previous
            let maximumStep = 0.8 * elapsed
            level = previous + min(maximumStep, max(-maximumStep, alpha * difference))
        } else { level = measurement }
        lastValid = time; lastUpdate = time
        return level
    }
}
