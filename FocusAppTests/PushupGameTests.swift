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
    private func started() -> PushupGame {
        var game = PushupGame()
        _ = game.apply(command(.ready, game), player: 0)
        _ = game.apply(command(.ready, game), player: 1)
        return game
    }
    func testBothPlayersMustBeReady() {
        var game = PushupGame()
        XCTAssertFalse(game.apply(command(.draw, game), player: 0))
        XCTAssertTrue(game.apply(command(.ready, game), player: 1))
        XCTAssertEqual(game.phase, .preparing)
        XCTAssertFalse(game.apply(command(.ready, game), player: 1))
        XCTAssertTrue(game.apply(command(.ready, game), player: 0))
        XCTAssertEqual(game.phase, .playing)
        XCTAssertEqual(game.turn, 0)
        XCTAssertTrue(game.isValid)
    }
    func testEveryCardIsReachableAndDrawnOnlyOncePerTurn() {
        for card in PushupCard.allCases {
            var game = started()
            var draws = 0
            XCTAssertTrue(game.apply(command(.draw, game), player: 0, draw: { draws += 1; return card }))
            XCTAssertEqual(game.card, card)
            XCTAssertFalse(game.apply(command(.draw, game), player: 0, draw: { draws += 1; return .three }))
            XCTAssertEqual(draws, 1)
            XCTAssertEqual(game.card, card)
        }
        XCTAssertEqual(Set(PushupCard.allCases.map(\.rawValue)), ["1", "2", "3", "SKIP"])
    }
    func testDoneRequiresRevealedCardAndAlternatesPlayers() {
        var game = started()
        XCTAssertFalse(game.apply(command(.done, game), player: 0))
        XCTAssertFalse(game.apply(command(.draw, game), player: 1))
        _ = game.apply(command(.draw, game), player: 0, draw: { .two })
        XCTAssertFalse(game.apply(command(.done, game), player: 1))
        XCTAssertTrue(game.apply(command(.done, game), player: 0))
        XCTAssertEqual(game.turn, 1)
        XCTAssertNil(game.card)
        _ = game.apply(command(.draw, game), player: 1, draw: { .one })
        XCTAssertTrue(game.apply(command(.done, game), player: 1))
        XCTAssertEqual(game.turn, 0)
        XCTAssertNil(game.loser)
    }
    func testSkipRemainsVisibleUntilDoneThenPassesNormally() {
        var game = started()
        _ = game.apply(command(.draw, game), player: 0, draw: { .skip })
        XCTAssertEqual(game.card, .skip)
        XCTAssertEqual(game.turn, 0)
        XCTAssertTrue(game.apply(command(.done, game), player: 0))
        XCTAssertEqual(game.turn, 1)
        XCTAssertNil(game.card)
        XCTAssertEqual(game.phase, .playing)
    }
    func testFirstGiveUpFinishesGameAndCannotBeOverwritten() {
        for loser in 0..<2 {
            var game = started()
            XCTAssertTrue(game.apply(command(.giveUp, game), player: loser))
            let final = game
            XCTAssertEqual(game.loser, loser)
            XCTAssertEqual(game.phase, .finished)
            XCTAssertFalse(game.apply(command(.giveUp, game), player: 1 - loser))
            XCTAssertFalse(game.apply(command(.done, game), player: loser))
            XCTAssertFalse(game.apply(command(.draw, game), player: loser))
            XCTAssertEqual(game, final)
            XCTAssertTrue(game.isValid)
        }
    }
    func testStaleTapAndPreviousGameCannotAdvanceNewTurn() {
        var game = started()
        let stale = command(.draw, game)
        _ = game.apply(stale, player: 0, draw: { .one })
        _ = game.apply(command(.done, game), player: 0)
        _ = game.apply(command(.draw, game), player: 1, draw: { .skip })
        _ = game.apply(command(.done, game), player: 1)
        XCTAssertFalse(game.apply(stale, player: 0))
        var newGame = started()
        XCTAssertFalse(newGame.apply(command(.giveUp, game), player: 0))
        XCTAssertFalse(newGame.apply(command(.draw, newGame), player: 2))
    }
    func testNewGameResetsReadyTurnCardAndResult() {
        var game = started()
        _ = game.apply(command(.draw, game), player: 0, draw: { .three })
        _ = game.apply(command(.giveUp, game), player: 0)
        let oldID = game.id
        game = PushupGame()
        XCTAssertNotEqual(game.id, oldID)
        XCTAssertEqual(game.ready, [false, false])
        XCTAssertEqual(game.turn, 0)
        XCTAssertNil(game.card)
        XCTAssertNil(game.loser)
        XCTAssertTrue(game.isValid)
    }
}
