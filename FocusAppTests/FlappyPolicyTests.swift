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
    func testEyeFilterRespondsWithoutOvershootAndPausesOnLoss() throws {
        var filter = EyeTrackingFilter()
        XCTAssertEqual(filter.update(0.5, at: 0), 0.5)
        let moved = try XCTUnwrap(filter.update(0.8, at: 0.12))
        XCTAssertGreaterThan(moved, 0.5)
        XCTAssertLessThanOrEqual(moved, 0.596001)
        XCTAssertEqual(filter.update(nil, at: 0.15), moved)
        XCTAssertNil(filter.update(nil, at: 0.4))
        XCTAssertEqual(filter.update(0.2, at: 0.5), 0.2)
        XCTAssertNil(filter.update(.nan, at: 1))
    }
    func testEyeSmoothingIsIndependentOfFrameRate() throws {
        var thirty = EyeTrackingFilter()
        var sixty = EyeTrackingFilter()
        _ = thirty.update(0.3, at: 0); _ = sixty.update(0.3, at: 0)
        for frame in 1...3 { _ = thirty.update(0.4, at: Double(frame) / 30) }
        for frame in 1...6 { _ = sixty.update(0.4, at: Double(frame) / 60) }
        XCTAssertEqual(try XCTUnwrap(thirty.level), try XCTUnwrap(sixty.level), accuracy: 0.000001)
    }
    func testEyePositionControlsVerticalAxisWithoutGazeInput() throws {
        XCTAssertEqual(try XCTUnwrap(EyeTrackingPolicy.screenLevel(eyeY: 0.5)), 0.5)
        XCTAssertLessThan(try XCTUnwrap(EyeTrackingPolicy.screenLevel(eyeY: 0.7)), 0.5)
        XCTAssertGreaterThan(try XCTUnwrap(EyeTrackingPolicy.screenLevel(eyeY: 0.3)), 0.5)
        XCTAssertNil(EyeTrackingPolicy.screenLevel(eyeY: .nan))
        XCTAssertNil(EyeTrackingPolicy.screenLevel(eyeY: 2))
    }
    func testSuddenTiltCannotProduceAnUnboundedJump() throws {
        var filter = EyeTrackingFilter()
        _ = filter.update(0.2, at: 0)
        let next = try XCTUnwrap(filter.update(0.9, at: 1.0 / 30))
        XCTAssertLessThanOrEqual(next - 0.2, 0.8 / 30 + 0.000001)
        XCTAssertEqual(filter.update(0.2, at: 1.0 / 30), next)
    }
    func testNoddingAndRollingAreVetoesNotControlInputs() throws {
        var filter = EyeTrackingFilter()
        XCTAssertEqual(filter.update(0.5, pitch: 0.3, roll: 0.1, at: 0), 0.5)
        // Moving projected eyes due only to a large nod or roll must not steer.
        XCTAssertEqual(filter.update(0.8, pitch: 0.6, roll: 0.1, at: 0.1), 0.5)
        XCTAssertEqual(filter.update(0.2, pitch: 0.3, roll: 0.4, at: 0.2), 0.5)
        XCTAssertEqual(filter.update(0.5, pitch: 0.3, roll: 0.1, at: 0.3), 0.5)
        let translated = try XCTUnwrap(filter.update(0.7, pitch: 0.3, roll: 0.1, at: 0.42))
        XCTAssertGreaterThan(translated, 0.5)
        XCTAssertLessThan(translated, 0.7)
        XCTAssertNil(filter.update(nil, at: 1))
        // Reacquisition can establish a new natural posture, not stay stuck
        // behind a calibration from before the camera lost the face.
        XCTAssertEqual(filter.update(0.4, pitch: 0.8, roll: 0.1, at: 1.1), 0.4)
    }
    func testEyeCornersIgnoreEyelidShapeAndHaveNoPupilInput() throws {
        let open = [CGPoint(x: 0.2, y: 0.4), CGPoint(x: 0.3, y: 0.5), CGPoint(x: 0.4, y: 0.4), CGPoint(x: 0.3, y: 0.3)]
        let closed = [CGPoint(x: 0.2, y: 0.4), CGPoint(x: 0.3, y: 0.41), CGPoint(x: 0.4, y: 0.4), CGPoint(x: 0.3, y: 0.39)]
        let a = try XCTUnwrap(EyeTrackingPolicy.eyeCornerCenter(open))
        XCTAssertEqual(a, EyeTrackingPolicy.eyeCornerCenter(closed))
        XCTAssertEqual(a.x, 0.3, accuracy: 0.000001)
        XCTAssertEqual(a.y, 0.4, accuracy: 0.000001)
        XCTAssertNil(EyeTrackingPolicy.eyeCornerCenter([]))
    }
    func testReferenceMatchesAspectFillPreviewCropping() {
        XCTAssertEqual(EyeTrackingPolicy.previewCoordinate(0.25, imageWidth: 720, imageHeight: 1280, viewWidth: 400, viewHeight: 400, horizontal: true), 100, accuracy: 0.000001)
        XCTAssertEqual(EyeTrackingPolicy.previewCoordinate(0.25, imageWidth: 720, imageHeight: 1280, viewWidth: 400, viewHeight: 400, horizontal: false), 22.222222, accuracy: 0.000001)
        XCTAssertEqual(EyeTrackingPolicy.previewCoordinate(0.5, imageWidth: 720, imageHeight: 1280, viewWidth: 320, viewHeight: 568, horizontal: false), 284, accuracy: 0.000001)
    }

}
