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
    func testEveryWaitRequiresContinuousFreshFaceFrames() {
        for seconds in TimePolicy.waitDurations where seconds > 0 {
            var wait = UnlockWait()
            wait.start(seconds: seconds, uptime: 100)
            XCTAssertEqual(wait.remaining(uptime: 500), seconds) // Time alone earns nothing.
            for tick in 0..<(seconds * 4) {
                let time = 100 + Double(tick) / 4
                wait.observeFace(visible: true, uptime: time)
                XCTAssertFalse(wait.completed(uptime: time))
            }
            wait.observeFace(visible: true, uptime: 100 + Double(seconds))
            XCTAssertTrue(wait.completed(uptime: 100 + Double(seconds)))
            XCTAssertFalse(wait.completed(uptime: 10))
        }
    }
    func testFaceLossOrCameraStallResetsEntireWait() {
        var wait = UnlockWait()
        wait.start(seconds: 10, uptime: 100)
        for tick in 0...20 { wait.observeFace(visible: true, uptime: 100 + Double(tick) / 4) }
        XCTAssertEqual(wait.remaining(uptime: 105), 5)
        wait.observeFace(visible: false, uptime: 105.1)
        XCTAssertEqual(wait.remaining(uptime: 105.1), 10)
        for tick in 0...20 { wait.observeFace(visible: true, uptime: 106 + Double(tick) / 4) }
        XCTAssertEqual(wait.remaining(uptime: 111), 5)
        XCTAssertEqual(wait.remaining(uptime: 112), 10) // No fresh frame.
        wait.observeFace(visible: true, uptime: 112)
        XCTAssertEqual(wait.remaining(uptime: 112), 10)
        XCTAssertFalse(wait.completed(uptime: 200))
        wait.cancel()
        wait.observeFace(visible: true, uptime: 200)
        XCTAssertNil(wait.remaining(uptime: 200))
    }
    func testClockChangesDuplicateFramesAndRestartCannotEarnTime() {
        var wait = UnlockWait()
        wait.start(seconds: 10, uptime: 100)
        for _ in 0..<100 { wait.observeFace(visible: true, uptime: 100) }
        XCTAssertEqual(wait.remaining(uptime: 100), 10)
        wait.observeFace(visible: true, uptime: .nan)
        wait.observeFace(visible: true, uptime: 10)
        XCTAssertEqual(wait.remaining(uptime: 100), 10)
        wait.start(seconds: 10, uptime: 200)
        XCTAssertEqual(wait.remaining(uptime: 200), 10)
    }
    func testSettingsRequireActualGrantNotFinishedWaitIncludingNone() {
        for seconds in TimePolicy.waitDurations {
            var wait = UnlockWait()
            wait.start(seconds: seconds, uptime: 100)
            XCTAssertEqual(wait.completed(uptime: 200), seconds == 0)
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
