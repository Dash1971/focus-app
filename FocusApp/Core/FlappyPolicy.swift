import Foundation

struct FlappyDifficulty {
    let activeSeconds: TimeInterval
    private var progress: Double { min(49, max(0, activeSeconds) / 20) / 49 }
    var level: Int { 1 + Int(min(49, max(0, activeSeconds) / 20)) }
    var speed: Double { 132 + 98 * progress }
    var gapHeight: Double { 158 - 38 * progress }
    var spawnInterval: Double { 1.75 - 0.55 * progress }
}

struct NoseTrackingFilter {
    private(set) var level: Double?
    private var lastValid: TimeInterval?
    private var lastUpdate: TimeInterval?

    mutating func update(_ measurement: Double?, at time: TimeInterval) -> Double? {
        guard let measurement, measurement.isFinite, (0...1).contains(measurement) else {
            if let lastValid, time - lastValid <= 0.18 { return level }
            level = nil
            lastUpdate = nil
            return nil
        }
        let elapsed = max(0, time - (lastUpdate ?? time))
        let alpha = 1 - exp(-elapsed / 0.06)
        if let previous = level, let lastValid, time - lastValid < 0.2 {
            level = previous + alpha * (measurement - previous)
        } else { level = measurement }
        lastValid = time
        lastUpdate = time
        return level
    }
}
