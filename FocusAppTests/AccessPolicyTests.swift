import XCTest
#if canImport(LockInCore)
@testable import LockInCore
#else
@testable import LockIn
#endif

final class AccessPolicyTests: XCTestCase {
    func testNoneIsImmediateButUnstartedOrCancelledWaitIsNeverComplete() {
        var wait = UnlockWait()
        XCTAssertFalse(wait.completed(uptime: 100))
        wait.start(seconds: 0, uptime: 100)
        XCTAssertEqual(wait.remaining(uptime: 100), 0)
        XCTAssertTrue(wait.completed(uptime: 100))
        wait.cancel()
        XCTAssertNil(wait.remaining(uptime: 200))
        XCTAssertFalse(wait.completed(uptime: 200))
        XCTAssertTrue(TimePolicy.waitDurations.contains(0))
    }
    func testEveryWaitCompletesOnlyAtItsDeadline() {
        for seconds in TimePolicy.waitDurations where seconds > 0 {
            var wait = UnlockWait()
            wait.start(seconds: seconds, uptime: 100)
            XCTAssertEqual(wait.remaining(uptime: 100), seconds)
            XCTAssertFalse(wait.completed(uptime: 100 + Double(seconds) - 0.01))
            XCTAssertTrue(wait.completed(uptime: 100 + Double(seconds)))
            XCTAssertFalse(wait.completed(uptime: 10)) // reboot/invalid uptime
        }
    }
    func testSettingsRequireActualGrantNotFinishedWaitIncludingNone() {
        for seconds in TimePolicy.waitDurations {
            var wait = UnlockWait()
            wait.start(seconds: seconds, uptime: 100)
            XCTAssertTrue(wait.completed(uptime: 200))
            XCTAssertFalse(RestrictionAccessPolicy.canEdit(hasSelection: true, authorized: true, activeGrant: false))
            XCTAssertTrue(RestrictionAccessPolicy.canEdit(hasSelection: true, authorized: true, activeGrant: true))
        }
        XCTAssertFalse(RestrictionAccessPolicy.canEdit(hasSelection: true, authorized: false, activeGrant: true))
        XCTAssertTrue(RestrictionAccessPolicy.canEdit(hasSelection: false, authorized: true, activeGrant: false))
    }
    func testShieldSelectionPlanSelectUnlockRelockFlow() {
        func plan(active: Bool) -> ShieldSelection<String, String, String> {
            ShieldSelection(apps: ["A", "B"], categories: ["Social"], domains: ["example.com"],
                            unlockedApps: ["A"], unlockedCategories: [], unlockedDomains: [], activeGrant: active)
        }
        let blocked = plan(active: false)
        XCTAssertEqual(blocked.applications, ["A", "B"])
        XCTAssertEqual(blocked.categories, ["Social"])
        XCTAssertEqual(blocked.domains, ["example.com"])
        XCTAssertTrue(blocked.applicationExceptions.isEmpty)
        let access = plan(active: true)
        XCTAssertEqual(access.applications, ["B"])
        XCTAssertEqual(access.categories, ["Social"])
        XCTAssertEqual(access.applicationExceptions, ["A"])
        let relocked = plan(active: false)
        XCTAssertEqual(relocked.applications, blocked.applications)
        XCTAssertEqual(relocked.categories, blocked.categories)
        XCTAssertTrue(relocked.applicationExceptions.isEmpty)
    }
    func testCategoryAndWebsiteGrantsDoNotRemoveUnrelatedShields() {
        let plan = ShieldSelection(apps: ["A"], categories: ["Social", "Games"], domains: ["A.com", "B.com"],
                                   unlockedApps: Set<String>(), unlockedCategories: ["Social"], unlockedDomains: ["A.com"], activeGrant: true)
        XCTAssertEqual(plan.applications, ["A"])
        XCTAssertEqual(plan.categories, ["Games"])
        XCTAssertEqual(plan.domains, ["B.com"])
        XCTAssertEqual(plan.domainExceptions, ["A.com"])
    }
}
