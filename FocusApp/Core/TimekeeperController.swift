import Foundation
import Combine
import UserNotifications
import UIKit
import AudioToolbox

extension Notification.Name {
    static let lockInNotificationFired = Notification.Name("lockIn.notificationFired")
}

enum LockInNotification {
    static let alarmCategory = "LOCKIN_ALARM"
    static let timerCategory = "LOCKIN_TIMER"
    static let stopAction = "LOCKIN_STOP"
    static let countdownIdentifier = "timer.countdown"

    static func alarmIdentifier(_ id: UUID, suffix: String) -> String {
        "alarm.\(id.uuidString).\(suffix)"
    }

    static func allIdentifiers(for alarm: Alarm) -> [String] {
        [alarmIdentifier(alarm.id, suffix: "once")]
            + (1...7).map { alarmIdentifier(alarm.id, suffix: "weekday.\($0)") }
    }
}

struct ActiveTimerSignal: Identifiable {
    let id: String
    let title: String
    let message: String
}

@MainActor
final class TimekeeperController: ObservableObject {
    @Published private(set) var state = TimekeeperState()
    @Published private(set) var now = Date()
    @Published var activeSignal: ActiveTimerSignal?
    @Published var notificationError: String?

    private let store: TimekeeperStore
    private let notifications = UNUserNotificationCenter.current()
    private var ticker: Foundation.Timer?
    private var notificationObserver: NSObjectProtocol?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        store = TimekeeperStore(url: support.appendingPathComponent("timekeeper.v1.json"))
        do {
            state = try store.load()
        } catch {
            notificationError = "Saved timers and alarms could not be read. \(error.localizedDescription)"
        }

        reconcile(at: .now)
        ticker = Foundation.Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .lockInNotificationFired,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in self?.receive(notification) }
        }
    }

    deinit {
        ticker?.invalidate()
        if let notificationObserver { NotificationCenter.default.removeObserver(notificationObserver) }
    }

    var countdownRemaining: Int { state.countdown.remaining(at: now) }
    var stopwatchElapsed: TimeInterval { state.stopwatch.elapsed(at: now) }

    func refresh() {
        reconcile(at: .now)
        rescheduleActiveNotifications()
    }

    func startCountdown(seconds: Int) {
        guard seconds > 0 else { return }
        let deadline = Date().addingTimeInterval(TimeInterval(seconds))
        state.countdown = CountdownState(
            durationSeconds: seconds,
            pausedRemainingSeconds: seconds,
            deadline: deadline
        )
        save()
        scheduleCountdown(deadline: deadline)
    }

    func pauseCountdown() {
        guard state.countdown.isRunning else { return }
        state.countdown.pausedRemainingSeconds = state.countdown.remaining(at: .now)
        state.countdown.deadline = nil
        notifications.removePendingNotificationRequests(withIdentifiers: [LockInNotification.countdownIdentifier])
        save()
    }

    func resumeCountdown() {
        let remaining = state.countdown.pausedRemainingSeconds
        guard !state.countdown.isRunning, remaining > 0 else { return }
        let deadline = Date().addingTimeInterval(TimeInterval(remaining))
        state.countdown.deadline = deadline
        save()
        scheduleCountdown(deadline: deadline)
    }

    func resetCountdown() {
        notifications.removePendingNotificationRequests(withIdentifiers: [LockInNotification.countdownIdentifier])
        state.countdown.deadline = nil
        state.countdown.pausedRemainingSeconds = state.countdown.durationSeconds
        save()
    }

    func startStopwatch() {
        guard !state.stopwatch.isRunning else { return }
        state.stopwatch.startedAt = .now
        save()
    }

    func pauseStopwatch() {
        guard state.stopwatch.isRunning else { return }
        state.stopwatch.elapsedBeforeRun = state.stopwatch.elapsed(at: .now)
        state.stopwatch.startedAt = nil
        save()
    }

    func resetStopwatch() {
        state.stopwatch = StopwatchState()
        save()
    }

    @discardableResult
    func saveAlarm(_ alarm: Alarm) -> Bool {
        guard !alarm.enabled || alarm.nextFireDate(after: .now) != nil else {
            notificationError = alarm.isRepeating
                ? "Choose at least one future repeat day."
                : "Choose a future date and time for this alarm."
            return false
        }

        if let index = state.alarms.firstIndex(where: { $0.id == alarm.id }) {
            state.alarms[index] = alarm
        } else {
            state.alarms.append(alarm)
        }
        state.alarms.sort { lhs, rhs in
            (lhs.nextFireDate(after: .now) ?? .distantFuture)
                < (rhs.nextFireDate(after: .now) ?? .distantFuture)
        }
        save()
        schedule(alarm)
        return true
    }

    func setAlarmEnabled(_ id: UUID, enabled: Bool) {
        guard let index = state.alarms.firstIndex(where: { $0.id == id }) else { return }
        var alarm = state.alarms[index]
        alarm.enabled = enabled
        if enabled, alarm.nextFireDate(after: .now) == nil {
            notificationError = "Edit this alarm and choose a future time before enabling it."
            return
        }
        state.alarms[index] = alarm
        save()
        schedule(alarm)
    }

    func deleteAlarm(_ id: UUID) {
        guard let alarm = state.alarms.first(where: { $0.id == id }) else { return }
        notifications.removePendingNotificationRequests(
            withIdentifiers: LockInNotification.allIdentifiers(for: alarm)
        )
        state.alarms.removeAll { $0.id == id }
        save()
    }

    func dismissSignal() {
        if let id = activeSignal?.id {
            notifications.removeDeliveredNotifications(withIdentifiers: [id])
        }
        activeSignal = nil
    }

    private func tick() {
        now = .now
        if let deadline = state.countdown.deadline, deadline <= now {
            state.countdown.deadline = nil
            state.countdown.pausedRemainingSeconds = 0
            save()
        }
        disableExpiredOneTimeAlarms(at: now)
    }

    private func reconcile(at date: Date) {
        now = date
        if let deadline = state.countdown.deadline, deadline <= date {
            state.countdown.deadline = nil
            state.countdown.pausedRemainingSeconds = 0
        }
        disableExpiredOneTimeAlarms(at: date)
        save()
    }

    private func disableExpiredOneTimeAlarms(at date: Date) {
        var changed = false
        for index in state.alarms.indices {
            let alarm = state.alarms[index]
            if alarm.enabled, !alarm.isRepeating, let fireDate = alarm.oneTimeDate, fireDate <= date {
                state.alarms[index].enabled = false
                changed = true
            }
        }
        if changed { save() }
    }

    private func save() {
        do {
            try store.save(state)
        } catch {
            notificationError = "Timers and alarms could not be saved. \(error.localizedDescription)"
        }
    }

    private func rescheduleActiveNotifications() {
        if let deadline = state.countdown.deadline, deadline > Date() {
            scheduleCountdown(deadline: deadline)
        }
        for alarm in state.alarms { schedule(alarm) }
    }

    private func scheduleCountdown(deadline: Date) {
        notifications.removePendingNotificationRequests(withIdentifiers: [LockInNotification.countdownIdentifier])
        Task {
            guard await requestNotificationPermission(),
                  state.countdown.deadline == deadline,
                  deadline > Date() else { return }
            let content = UNMutableNotificationContent()
            content.title = "Countdown complete"
            content.body = "Time is up."
            content.sound = .default
            content.categoryIdentifier = LockInNotification.timerCategory
            let request = UNNotificationRequest(
                identifier: LockInNotification.countdownIdentifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: max(1, deadline.timeIntervalSinceNow),
                    repeats: false
                )
            )
            do { try await notifications.add(request) }
            catch { notificationError = "The countdown alert could not be scheduled. \(error.localizedDescription)" }
        }
    }

    private func schedule(_ alarm: Alarm) {
        notifications.removePendingNotificationRequests(
            withIdentifiers: LockInNotification.allIdentifiers(for: alarm)
        )
        guard alarm.enabled else { return }

        Task {
            guard await requestNotificationPermission(),
                  state.alarms.contains(alarm) else { return }

            let content = UNMutableNotificationContent()
            content.title = "Alarm"
            content.body = "Your alarm is ringing."
            content.sound = .default
            content.categoryIdentifier = LockInNotification.alarmCategory

            do {
                if alarm.isRepeating {
                    for weekday in alarm.repeatWeekdays.sorted() {
                        var components = DateComponents()
                        components.calendar = .current
                        components.timeZone = .current
                        components.weekday = weekday
                        components.hour = alarm.timeMinutes / 60
                        components.minute = alarm.timeMinutes % 60
                        let request = UNNotificationRequest(
                            identifier: LockInNotification.alarmIdentifier(
                                alarm.id,
                                suffix: "weekday.\(weekday)"
                            ),
                            content: content,
                            trigger: UNCalendarNotificationTrigger(
                                dateMatching: components,
                                repeats: true
                            )
                        )
                        try await notifications.add(request)
                    }
                } else if let date = alarm.oneTimeDate, date > Date() {
                    var components = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute],
                        from: date
                    )
                    components.calendar = .current
                    components.timeZone = .current
                    let request = UNNotificationRequest(
                        identifier: LockInNotification.alarmIdentifier(alarm.id, suffix: "once"),
                        content: content,
                        trigger: UNCalendarNotificationTrigger(
                            dateMatching: components,
                            repeats: false
                        )
                    )
                    try await notifications.add(request)
                }
            } catch {
                notificationError = "The alarm could not be scheduled. \(error.localizedDescription)"
            }
        }
    }

    private func requestNotificationPermission() async -> Bool {
        do {
            let settings = await notifications.notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                return true
            case .notDetermined:
                let granted = try await notifications.requestAuthorization(options: [.alert, .sound])
                if !granted { notificationError = "Enable notifications in Settings so timers and alarms can alert you in the background." }
                return granted
            default:
                notificationError = "Enable notifications in Settings so timers and alarms can alert you in the background."
                return false
            }
        } catch {
            notificationError = "Notification permission could not be requested. \(error.localizedDescription)"
            return false
        }
    }

    private func receive(_ notification: Notification) {
        let response = notification.userInfo?["response"] as? UNNotificationResponse
        let delivered = notification.userInfo?["notification"] as? UNNotification
        guard let systemNotification = response?.notification ?? delivered else { return }
        if response?.actionIdentifier == LockInNotification.stopAction {
            notifications.removeDeliveredNotifications(withIdentifiers: [systemNotification.request.identifier])
            return
        }
        let content = systemNotification.request.content
        activeSignal = ActiveTimerSignal(
            id: systemNotification.request.identifier,
            title: content.title,
            message: content.body
        )
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

final class NotificationBridge: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let stop = UNNotificationAction(
            identifier: LockInNotification.stopAction,
            title: "Stop",
            options: [.foreground]
        )
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: LockInNotification.alarmCategory,
                actions: [stop],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: LockInNotification.timerCategory,
                actions: [stop],
                intentIdentifiers: []
            )
        ])
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        NotificationCenter.default.post(
            name: .lockInNotificationFired,
            object: nil,
            userInfo: ["notification": notification]
        )
        return [.sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        NotificationCenter.default.post(
            name: .lockInNotificationFired,
            object: nil,
            userInfo: ["response": response]
        )
    }
}
