import Foundation

struct UnlockWait {
    private(set) var startedUptime: TimeInterval?
    private(set) var requiredSeconds = 0
    private(set) var visibleSeconds: TimeInterval = 0
    private var lastFaceUptime: TimeInterval?
    private var lastFrameUptime: TimeInterval?
    private var missingSince: TimeInterval?
    // An uncertain detection pauses, but earns no time. Confirm absence across
    // fresh frames before resetting; a stalled camera still resets immediately.
    static let maximumFrameGap: TimeInterval = 0.5
    static let absenceConfirmation: TimeInterval = 0.75

    mutating func start(seconds: Int, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        requiredSeconds = TimePolicy.waitDurations.contains(seconds) ? seconds : 10
        startedUptime = uptime
        resetProgress()
    }
    mutating func resetProgress() {
        visibleSeconds = 0; lastFaceUptime = nil; lastFrameUptime = nil; missingSince = nil
    }
    mutating func cancel() { startedUptime = nil; resetProgress() }
    mutating func observeFace(visible: Bool, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard let startedUptime, uptime.isFinite, uptime >= startedUptime,
              visibleSeconds < Double(requiredSeconds),
              uptime >= (lastFrameUptime ?? startedUptime) else { return }
        if let lastFrameUptime, uptime - lastFrameUptime > Self.maximumFrameGap { resetProgress() }
        lastFrameUptime = uptime
        guard visible else {
            lastFaceUptime = nil
            if missingSince == nil { missingSince = uptime }
            if uptime - (missingSince ?? uptime) >= Self.absenceConfirmation { visibleSeconds = 0 }
            return
        }
        if let missingSince, uptime - missingSince >= Self.absenceConfirmation { visibleSeconds = 0 }
        missingSince = nil
        if let lastFaceUptime { visibleSeconds += uptime - lastFaceUptime }
        lastFaceUptime = uptime
    }
    func remaining(uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Int? {
        guard let startedUptime, uptime.isFinite, uptime >= startedUptime else { return nil }
        if visibleSeconds >= Double(requiredSeconds) { return 0 }
        guard let lastFrameUptime, uptime >= lastFrameUptime,
              uptime - lastFrameUptime <= Self.maximumFrameGap else { return requiredSeconds }
        if let missingSince, uptime - missingSince >= Self.absenceConfirmation { return requiredSeconds }
        return max(0, Int(ceil(Double(requiredSeconds) - visibleSeconds)))
    }
    func completed(uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool { remaining(uptime: uptime) == 0 }
}

enum RestrictionAccessPolicy {
    static func canEdit(hasSelection: Bool, authorized: Bool, activeGrant: Bool) -> Bool {
        authorized && (!hasSelection || activeGrant)
    }
}

// The native adapter supplies Apple's opaque tokens. Pure set operations can
// be tested without manufacturing or depending on their private token encoding.
struct ShieldSelection<A: Hashable, C: Hashable, W: Hashable> {
    let applications: Set<A>
    let categories: Set<C>
    let domains: Set<W>
    let applicationExceptions: Set<A>
    let domainExceptions: Set<W>

    init(apps: Set<A>, categories: Set<C>, domains: Set<W>,
         unlockedApps: Set<A>, unlockedCategories: Set<C>, unlockedDomains: Set<W>, activeGrant: Bool) {
        applications = activeGrant ? apps.subtracting(unlockedApps) : apps
        self.categories = activeGrant ? categories.subtracting(unlockedCategories) : categories
        self.domains = activeGrant ? domains.subtracting(unlockedDomains) : domains
        applicationExceptions = activeGrant ? unlockedApps : []
        domainExceptions = activeGrant ? unlockedDomains : []
    }
}
