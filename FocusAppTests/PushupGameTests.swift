import XCTest
#if canImport(LockInCore)
@testable import LockInCore
#else
@testable import LockIn
#endif

final class PushupGameTests: XCTestCase {
    private func command(_ action: PushupAction, _ game: PushupGame) -> PushupCommand {
        PushupCommand(gameID: game.id, revision: game.revision, action: action)
    }

    private func started(_ count: Int) -> PushupGame {
        var game = PushupGame(playerCount: count)
        for player in 0..<count { XCTAssertTrue(game.apply(command(.ready, game), player: player)) }
        return game
    }

    func testPlayerSelectionAndReadiness() {
        for count in 2...4 {
            var game = PushupGame(playerCount: count)
            XCTAssertEqual(game.ready.count, count)
            XCTAssertFalse(game.apply(command(.draw, game), player: 0))
            for player in 0..<(count - 1) {
                XCTAssertTrue(game.apply(command(.ready, game), player: player))
                XCTAssertEqual(game.phase, .preparing)
            }
            XCTAssertTrue(game.apply(command(.ready, game), player: count - 1))
            XCTAssertEqual(game.phase, .playing)
            XCTAssertTrue(game.isValid)
        }
    }

    func testTenRoundsForEveryPlayerCountAndEveryCard() {
        for count in 2...4 {
            var game = started(count)
            for round in 1...10 {
                for player in 0..<count {
                    XCTAssertEqual(game.round, round)
                    XCTAssertEqual(game.turn, player)
                    XCTAssertFalse(game.apply(command(.done, game), player: player))
                    let card = PushupCard.allCases[(round + player) % PushupCard.allCases.count]
                    XCTAssertTrue(game.apply(command(.draw, game), player: player, draw: { card }))
                    XCTAssertEqual(game.card, card)
                    XCTAssertFalse(game.apply(command(.draw, game), player: player))
                    XCTAssertTrue(game.apply(command(.done, game), player: player))
                }
            }
            XCTAssertEqual(game.phase, .finished)
            XCTAssertEqual(game.round, 10)
            XCTAssertTrue(game.isValid)
            XCTAssertFalse(game.apply(command(.draw, game), player: 0))
        }
        XCTAssertEqual(Set(PushupCard.allCases.map(\.rawValue)), ["1", "2", "3", "SKIP"])
    }

    func testStaleOrWrongPlayerCannotAdvanceRound() {
        var game = started(3)
        let stale = command(.draw, game)
        XCTAssertFalse(game.apply(command(.draw, game), player: 1))
        XCTAssertTrue(game.apply(stale, player: 0, draw: { .one }))
        XCTAssertFalse(game.apply(stale, player: 0))
        XCTAssertFalse(game.apply(command(.done, game), player: 2))
        XCTAssertEqual(game.round, 1)
        XCTAssertEqual(game.turn, 0)
    }
    func testFiveAndTenRoundTotalsForAllPlayerCounts() throws {
        for mode in [PushupRounds.five, .ten] {
            for count in 2...4 {
                var game = PushupGame(playerCount: count, rounds: mode)
                for player in 0..<count { XCTAssertTrue(game.apply(command(.ready, game), player: player)) }
                for round in 1...mode.limit! {
                    for player in 0..<count {
                        let card = PushupCard.allCases[(round + player) % 4]
                        XCTAssertTrue(game.apply(command(.draw, game), player: player, draw: { card }))
                        let done = command(.done, game)
                        XCTAssertTrue(game.apply(done, player: player))
                        XCTAssertFalse(game.apply(done, player: player))
                        XCTAssertEqual(game.roundPushups[round - 1][player], card.pushups)
                    }
                }
                XCTAssertEqual(game.completedRounds, mode.limit)
                XCTAssertEqual(game.phase, .finished)
                XCTAssertTrue(game.isValid)
                let expected = (0..<count).map { player in
                    (1...mode.limit!).reduce(0) { $0 + PushupCard.allCases[($1 + player) % 4].pushups }
                }
                XCTAssertEqual(game.playerTotals, expected)
                XCTAssertEqual(game.totalPushups, expected.reduce(0, +))
                let decoded = try JSONDecoder().decode(PushupGame.self, from: JSONEncoder().encode(game))
                XCTAssertEqual(decoded, game)
            }
        }
    }
    func testEndlessContinuesPastTenThenFinishesWithRecordedPartialRoundOnly() {
        for count in 2...4 {
            var game = PushupGame(playerCount: count, rounds: .endless)
            XCTAssertFalse(game.apply(command(.finish, game), player: 0))
            for player in 0..<count { _ = game.apply(command(.ready, game), player: player) }
            for _ in 1...12 {
                for player in 0..<count {
                    _ = game.apply(command(.draw, game), player: player, draw: { .two })
                    _ = game.apply(command(.done, game), player: player)
                }
            }
            XCTAssertEqual(game.phase, .playing)
            XCTAssertEqual(game.round, 13)
            _ = game.apply(command(.draw, game), player: 0, draw: { .skip })
            _ = game.apply(command(.done, game), player: 0)
            _ = game.apply(command(.draw, game), player: 1, draw: { .three })
            let finish = command(.finish, game)
            XCTAssertTrue(game.apply(finish, player: 1))
            XCTAssertFalse(game.apply(finish, player: 1))
            XCTAssertEqual(game.roundPushups.last?[0], 0)
            XCTAssertNil(game.roundPushups.last?[1]) // Drawn, never confirmed.
            XCTAssertEqual(game.playerTotals, Array(repeating: 24, count: count))
            XCTAssertEqual(game.totalPushups, count * 24)
            XCTAssertEqual(game.completedRounds, 12)
            XCTAssertTrue(game.isValid)
        }
    }
    func testFinishDoesNotInventFirstRoundResultsAndIsEndlessOnly() {
        var endless = PushupGame(rounds: .endless)
        for player in 0..<2 { _ = endless.apply(command(.ready, endless), player: player) }
        XCTAssertTrue(endless.apply(command(.finish, endless), player: 0))
        XCTAssertTrue(endless.roundPushups.isEmpty)
        XCTAssertEqual(endless.totalPushups, 0)
        var finite = started(2)
        XCTAssertFalse(finite.apply(command(.finish, finite), player: 0))
    }

}
