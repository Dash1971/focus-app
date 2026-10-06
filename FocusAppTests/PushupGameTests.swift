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
            for round in 1...PushupGame.totalRounds {
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
            XCTAssertEqual(game.round, PushupGame.totalRounds)
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
}
