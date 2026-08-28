import Foundation
import Combine
import FamilyControls
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published var selection: FamilyActivitySelection
    @Published var activeSession: ActiveFocusSession?
    @Published var schedules: [BlockSchedule]
    @Published var records: [FocusSessionRecord]
    @Published var challengesCompleted: Int
    @Published var emergencyUnlocks: Int
    @Published var customChallenges: [Challenge]
    @Published var lastError: String?

    let blocker = BlockingController.shared
    private let shared = SharedStore.shared
    private var completionTimer: Timer?

    init() {
        let snapshot = shared.load()
        selection = snapshot.selection
        activeSession = snapshot.activeSession
        schedules = snapshot.schedules
        records = snapshot.records
        challengesCompleted = snapshot.challengesCompleted
        emergencyUnlocks = snapshot.emergencyUnlocks
        customChallenges = snapshot.customChallenges
        reconcileSession()
    }

    var focusMinutesToday: Int {
        records.filter { Calendar.current.isDateInToday($0.endedAt) && $0.completed }
            .reduce(0) { $0 + $1.plannedMinutes }
    }

    var sessionsToday: Int {
        records.filter { Calendar.current.isDateInToday($0.endedAt) && $0.completed }.count
    }

    var focusMinutesThisWeek: Int {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return records.filter { interval.contains($0.endedAt) && $0.completed }.reduce(0) { $0 + $1.plannedMinutes }
    }

    var sessionsThisWeek: Int {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return records.filter { interval.contains($0.endedAt) && $0.completed }.count
    }

    var selectedItemCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    var activeScheduleNow: BlockSchedule? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: .now)
        let minute = calendar.component(.hour, from: .now) * 60 + calendar.component(.minute, from: .now)
        return schedules.first { schedule in
            guard schedule.enabled else { return false }
            if schedule.endMinutes > schedule.startMinutes {
                return schedule.weekdays.contains(weekday) && minute >= schedule.startMinutes && minute < schedule.endMinutes
            }
            if minute >= schedule.startMinutes { return schedule.weekdays.contains(weekday) }
            let previousWeekday = weekday == 1 ? 7 : weekday - 1
            return minute < schedule.endMinutes && schedule.weekdays.contains(previousWeekday)
        }
    }

    func authorize() async {
        do {
            try await blocker.requestAuthorization()
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            lastError = error.localizedDescription
        }
    }

    func updateSelection(_ value: FamilyActivitySelection) {
        selection = value
        persist()
        reinstallSchedules()
    }

    func beginFocus(minutes: Int, challenge: Challenge, selection chosenSelection: FamilyActivitySelection? = nil) {
        let chosen = chosenSelection ?? selection
        guard !chosen.applicationTokens.isEmpty || !chosen.categoryTokens.isEmpty || !chosen.webDomainTokens.isEmpty else {
            lastError = "Choose at least one app, category, or website first."
            return
        }
        do {
            let created = try blocker.startFocus(selection: chosen, minutes: minutes)
            activeSession = ActiveFocusSession(
                id: created.id,
                startedAt: created.startedAt,
                endsAt: created.endsAt,
                plannedMinutes: created.plannedMinutes,
                challenge: challenge,
                selection: chosen
            )
            scheduleFocusNotification(for: activeSession!)
            persist()
            armCompletionTimer()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func beginFocus(until end: Date, challenge: Challenge, selection: FamilyActivitySelection? = nil) {
        let minutes = max(1, Int(ceil(end.timeIntervalSinceNow / 60)))
        beginFocus(minutes: minutes, challenge: challenge, selection: selection)
    }

    func saveCustomChallenge(_ challenge: Challenge) {
        guard challenge.kind == .custom, !challenge.customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if !customChallenges.contains(challenge) { customChallenges.append(challenge) }
        persist()
    }

    func deleteCustomChallenges(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) { customChallenges.remove(at: index) }
        persist()
    }

    func completeChallengeAndUnlock() {
        challengesCompleted += 1
        finishSession(completed: false, emergency: false)
    }

    func emergencyUnlock() {
        emergencyUnlocks += 1
        finishSession(completed: false, emergency: true)
    }

    func unlockSchedule(_ schedule: BlockSchedule, completedChallenge: Bool, emergency: Bool) {
        if completedChallenge { challengesCompleted += 1 }
        if emergency { emergencyUnlocks += 1 }
        var disabled = schedule
        disabled.enabled = false
        saveSchedule(disabled)
    }

    func saveSchedule(_ schedule: BlockSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
        } else {
            guard schedules.count < 15 else {
                lastError = "LockIn supports up to 15 schedules in this version."
                return
            }
            schedules.append(schedule)
        }
        persist()
        let chosen = schedule.selection.isEmpty ? selection : schedule.selection
        do { try blocker.install(schedule, selection: chosen) }
        catch { lastError = error.localizedDescription }
    }

    func deleteSchedules(at offsets: IndexSet) {
        for index in offsets { blocker.remove(schedules[index]) }
        for index in offsets.sorted(by: >) { schedules.remove(at: index) }
        persist()
    }

    func setScheduleEnabled(_ schedule: BlockSchedule, enabled: Bool) {
        var updated = schedule
        updated.enabled = enabled
        saveSchedule(updated)
    }

    private func reinstallSchedules() {
        for schedule in schedules {
            let chosen = schedule.selection.isEmpty ? selection : schedule.selection
            do { try blocker.install(schedule, selection: chosen) }
            catch { lastError = error.localizedDescription }
        }
    }

    private func reconcileSession() {
        guard let session = activeSession else { return }
        if session.endsAt <= .now {
            finishSession(completed: true, emergency: false)
        } else {
            armCompletionTimer()
        }
    }

    private func armCompletionTimer() {
        completionTimer?.invalidate()
        guard let end = activeSession?.endsAt else { return }
        completionTimer = Timer.scheduledTimer(withTimeInterval: max(1, end.timeIntervalSinceNow), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finishSession(completed: true, emergency: false) }
        }
    }

    private func finishSession(completed: Bool, emergency: Bool) {
        completionTimer?.invalidate()
        guard let session = activeSession else {
            blocker.clearFocus()
            return
        }
        records.append(.init(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: .now,
            plannedMinutes: session.plannedMinutes,
            completed: completed,
            emergencyUnlock: emergency
        ))
        activeSession = nil
        blocker.clearFocus()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focus.session"])
        persist()
    }

    private func scheduleFocusNotification(for session: ActiveFocusSession) {
        let content = UNMutableNotificationContent()
        content.title = "LockIn session complete"
        content.body = "Your blocked apps are available again."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, session.endsAt.timeIntervalSinceNow), repeats: false)
        let request = UNNotificationRequest(identifier: "focus.session", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func persist() {
        shared.save(SharedSnapshot(
            selection: selection,
            activeSession: activeSession,
            schedules: schedules,
            records: records,
            challengesCompleted: challengesCompleted,
            emergencyUnlocks: emergencyUnlocks,
            customChallenges: customChallenges
        ))
    }
}

private extension FamilyActivitySelection {
    var isEmpty: Bool { applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty }
}
