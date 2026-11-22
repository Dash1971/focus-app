import Foundation

struct UnlockWait {
    private(set) var startedUptime: TimeInterval?
    private(set) var requiredSeconds = 0
    private(set) var visibleSeconds: TimeInterval = 0
    private var lastFaceUptime: TimeInterval?
    // Missing frames, interrupted capture and stalled delivery never earn time.
    static let maximumFrameGap: TimeInterval = 0.5

    mutating func start(seconds: Int, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        requiredSeconds = TimePolicy.waitDurations.contains(seconds) ? seconds : 10
        startedUptime = uptime
        visibleSeconds = 0
        lastFaceUptime = nil
    }
    mutating func cancel() { startedUptime = nil; visibleSeconds = 0; lastFaceUptime = nil }
    mutating func observeFace(visible: Bool, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard let startedUptime, uptime.isFinite, uptime >= startedUptime,
              visibleSeconds < Double(requiredSeconds) else { return }
        guard visible else { visibleSeconds = 0; lastFaceUptime = nil; return }
        if let lastFaceUptime, uptime >= lastFaceUptime,
           uptime - lastFaceUptime <= Self.maximumFrameGap {
            visibleSeconds += uptime - lastFaceUptime
        } else { visibleSeconds = 0 }
        lastFaceUptime = uptime
    }
    func remaining(uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Int? {
        guard let startedUptime, uptime.isFinite, uptime >= startedUptime else { return nil }
        if visibleSeconds >= Double(requiredSeconds) { return 0 }
        guard let lastFaceUptime, uptime >= lastFaceUptime,
              uptime - lastFaceUptime <= Self.maximumFrameGap else { return requiredSeconds }
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
