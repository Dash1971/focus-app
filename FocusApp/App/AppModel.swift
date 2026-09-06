import Foundation
import Combine
import FamilyControls
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var blocking = BlockingState()
    @Published private(set) var life = LifeState()
    @Published private(set) var storageReady = false
    @Published private(set) var lifeReady = false
    @Published private(set) var authorized = false
    @Published private(set) var waitRemaining: Int?
    @Published var lastError: String?

    private let blocker = BlockingController()
    private let lifeStore = LifeStore(url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("life.v1.json"))
    private var waitStarted: TimeInterval?
    private var waitRequired = 10
    private var ticker: Timer?

    init() {
        do { life = try lifeStore.load(); lifeReady = true }
        catch { lastError = "Your saved notes, events and habits could not be read. Reopen LockIn to retry. \(error.localizedDescription)" }
        refreshFromSharedStore()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func refreshFromSharedStore() {
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        do { blocking = try blocker.reconcile(); storageReady = true }
        catch { storageReady = false; lastError = error.localizedDescription }
    }

    func authorize() async {
        do { try await blocker.requestAuthorization(); refreshFromSharedStore() }
        catch { lastError = error.localizedDescription }
    }

    func updateSelection(_ value: FamilyActivitySelection) {
        cancelWait()
        updateBlocking { try blocker.updateSelection(value) }
    }

    func setWait(_ seconds: Int) {
        guard TimePolicy.waitDurations.contains(seconds) else { return }
        cancelWait()
        updateBlocking { try SharedStore.shared.transaction { $0.waitSeconds = seconds } }
    }

    func startWait() {
        guard storageReady, authorized else { return }
        waitRequired = TimePolicy.waitDurations.contains(blocking.waitSeconds) ? blocking.waitSeconds : 10
        waitStarted = ProcessInfo.processInfo.systemUptime
        waitRemaining = waitRequired
    }

    func cancelWait() { waitStarted = nil; waitRemaining = nil }

    @discardableResult
    func unlock(_ selection: FamilyActivitySelection, seconds: Int) -> Bool {
        guard storageReady, let start = waitStarted,
              ProcessInfo.processInfo.systemUptime - start >= Double(waitRequired) else { return false }
        cancelWait()
        do {
            blocking = try blocker.unlock(selection, seconds: seconds)
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch { lastError = error.localizedDescription; return false }
    }

    func lockNow() { cancelWait(); updateBlocking { try blocker.lockNow() } }

    private func updateBlocking(_ operation: () throws -> BlockingState) {
        guard storageReady else { return }
        do { blocking = try operation(); WidgetCenter.shared.reloadAllTimelines() }
        catch { lastError = error.localizedDescription }
    }

    private func tick() {
        if let start = waitStarted {
            waitRemaining = max(0, Int(ceil(Double(waitRequired) - (ProcessInfo.processInfo.systemUptime - start))))
        }
        if blocking.grant?.deadline.isActive() == false { refreshFromSharedStore(); WidgetCenter.shared.reloadAllTimelines() }
    }

    @discardableResult
    func editLife(_ change: (inout LifeState) -> Void) -> Bool {
        guard lifeReady else { return false }
        var next = life
        change(&next)
        do { try lifeStore.save(next); life = next; return true }
        catch { lastError = "Your changes could not be saved. \(error.localizedDescription)"; return false }
    }

    func toggleHabit(_ id: UUID, date: Date) {
        guard Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: .now) else { return }
        editLife { state in
            guard let index = state.habits.firstIndex(where: { $0.id == id }) else { return }
            let key = TimePolicy.dayKey(date)
            if state.habits[index].completedDays.contains(key) { state.habits[index].completedDays.remove(key) }
            else { state.habits[index].completedDays.insert(key) }
        }
    }
}
