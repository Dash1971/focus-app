import XCTest
#if canImport(LockInCore)
@testable import LockInCore
#else
@testable import LockIn
#endif

final class FlappyPolicyTests: XCTestCase {
    func testDifficultyRisesGraduallyAndCapsAtFiftyForever() {
        let start = FlappyDifficulty(activeSeconds: 0)
        XCTAssertEqual(start.level, 1)
        XCTAssertEqual(start.speed, 132)
        for seconds in 1...980 {
            let before = FlappyDifficulty(activeSeconds: Double(seconds - 1))
            let after = FlappyDifficulty(activeSeconds: Double(seconds))
            XCTAssertGreaterThanOrEqual(after.speed, before.speed)
            XCTAssertLessThan(after.speed - before.speed, 0.11)
            XCTAssertLessThanOrEqual(after.gapHeight, before.gapHeight)
            XCTAssertLessThanOrEqual(after.spawnInterval, before.spawnInterval)
            XCTAssertLessThanOrEqual(after.level, 50)
        }
        let cap = FlappyDifficulty(activeSeconds: 980)
        let later = FlappyDifficulty(activeSeconds: 100_000)
        XCTAssertEqual(cap.level, 50)
        XCTAssertEqual(cap.speed, later.speed)
        XCTAssertEqual(cap.gapHeight, later.gapHeight)
        XCTAssertEqual(cap.spawnInterval, later.spawnInterval)
        XCTAssertGreaterThan(later.spawnInterval, 0)
    }
    func testNoSuddenSpeedJumpWhenLevelChanges() {
        let before = FlappyDifficulty(activeSeconds: 19.999)
        let after = FlappyDifficulty(activeSeconds: 20.001)
        XCTAssertEqual(before.level, 1)
        XCTAssertEqual(after.level, 2)
        XCTAssertEqual(before.speed, after.speed, accuracy: 0.001)
    }
    func testNoseFilterRespondsWithoutOvershootAndPausesOnLoss() throws {
        var filter = NoseTrackingFilter()
        XCTAssertEqual(filter.update(0.5, at: 0), 0.5)
        let moved = try XCTUnwrap(filter.update(0.8, at: 0.12))
        XCTAssertGreaterThan(moved, 0.5)
        XCTAssertLessThanOrEqual(moved, 0.596001)
        XCTAssertEqual(filter.update(nil, at: 0.15), moved)
        XCTAssertNil(filter.update(nil, at: 0.4))
        XCTAssertEqual(filter.update(0.2, at: 0.5), 0.2)
        XCTAssertNil(filter.update(.nan, at: 1))
    }
    func testNoseSmoothingIsIndependentOfFrameRate() throws {
        var thirty = NoseTrackingFilter()
        var sixty = NoseTrackingFilter()
        _ = thirty.update(0.3, at: 0); _ = sixty.update(0.3, at: 0)
        for frame in 1...3 { _ = thirty.update(0.4, at: Double(frame) / 30) }
        for frame in 1...6 { _ = sixty.update(0.4, at: Double(frame) / 60) }
        XCTAssertEqual(try XCTUnwrap(thirty.level), try XCTUnwrap(sixty.level), accuracy: 0.000001)
    }
    func testBridgePositionControlsVerticalAxisWithoutGazeInput() throws {
        XCTAssertEqual(try XCTUnwrap(NoseTrackingPolicy.screenLevel(bridgeY: 0.5)), 0.5)
        XCTAssertLessThan(try XCTUnwrap(NoseTrackingPolicy.screenLevel(bridgeY: 0.7)), 0.5)
        XCTAssertGreaterThan(try XCTUnwrap(NoseTrackingPolicy.screenLevel(bridgeY: 0.3)), 0.5)
        XCTAssertNil(NoseTrackingPolicy.screenLevel(bridgeY: .nan))
        XCTAssertNil(NoseTrackingPolicy.screenLevel(bridgeY: 2))
    }
    func testSuddenTiltCannotProduceAnUnboundedJump() throws {
        var filter = NoseTrackingFilter()
        _ = filter.update(0.2, at: 0)
        let next = try XCTUnwrap(filter.update(0.9, at: 1.0 / 30))
        XCTAssertLessThanOrEqual(next - 0.2, 0.8 / 30 + 0.000001)
        XCTAssertEqual(filter.update(0.2, at: 1.0 / 30), next)
    }
}
