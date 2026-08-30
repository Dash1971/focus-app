import Foundation
import Combine
import UserNotifications
import AudioToolbox

@MainActor
final class CountdownTimerModel: ObservableObject {
    @Published var durationSeconds = 20 * 60 {
        didSet {
            if !isRunning && !isPaused {
                remainingSeconds = max(1, durationSeconds)
            }
        }
    }
    @Published private(set) var remainingSeconds = 20 * 60
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published var sound: TimerSound = .bell

    private var endDate: Date?
    private var ticker: Timer?

    func start() {
        if !isPaused || remainingSeconds == 0 {
            remainingSeconds = max(1, durationSeconds)
        }
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        isRunning = true
        isPaused = false
        scheduleNotification(seconds: remainingSeconds, id: "normal.timer", title: "Timer complete", sound: sound)
        tick()
    }

    func pause() {
        updateRemaining()
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        isRunning = false
        isPaused = remainingSeconds > 0
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["normal.timer"])
    }

    func reset() {
        pause()
        isPaused = false
        remainingSeconds = durationSeconds
    }

    private func tick() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateRemaining() }
        }
    }

    private func updateRemaining() {
        guard let endDate else { return }
        remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        if remainingSeconds == 0 {
            ticker?.invalidate()
            ticker = nil
            self.endDate = nil
            isRunning = false
            isPaused = false
            play(sound)
        }
    }
}

@MainActor
final class IntervalTimerModel: ObservableObject {
    enum Phase: String { case work = "WORK", rest = "REST", complete = "COMPLETE" }

    @Published var configuration = IntervalConfiguration()
    @Published private(set) var phase: Phase = .work
    @Published private(set) var round = 1
    @Published private(set) var remainingSeconds = 40
    @Published private(set) var isRunning = false

    private var ticker: Timer?
    private var endDate: Date?

    func start() {
        phase = .work
        round = 1
        beginPhase(seconds: configuration.workSeconds)
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        isRunning = false
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["interval.timer"])
    }

    func advance() {
        switch phase {
        case .work:
            if round >= configuration.rounds { finish() }
            else { phase = .rest; beginPhase(seconds: configuration.restSeconds) }
        case .rest:
            round += 1
            phase = .work
            beginPhase(seconds: configuration.workSeconds)
        case .complete:
            start()
        }
    }

    private func beginPhase(seconds: Int) {
        remainingSeconds = max(1, seconds)
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        isRunning = true
        scheduleNotification(seconds: remainingSeconds, id: "interval.timer", title: "\(phase.rawValue) complete", sound: configuration.sound)
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard let endDate else { return }
        remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        if remainingSeconds == 0 {
            ticker?.invalidate()
            ticker = nil
            self.endDate = nil
            isRunning = false
            play(configuration.sound)
            if configuration.autoAdvance { advance() }
        }
    }

    private func finish() {
        stop()
        phase = .complete
        remainingSeconds = 0
    }
}

private func scheduleNotification(seconds: Int, id: String, title: String, sound: TimerSound) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.sound = sound == .silent ? nil : .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, seconds)), repeats: false)
    UNUserNotificationCenter.current().add(.init(identifier: id, content: content, trigger: trigger))
}

private func play(_ sound: TimerSound) {
    guard sound.systemSoundID != 0 else { return }
    AudioServicesPlaySystemSound(sound.systemSoundID)
}
