import Foundation

// Pure game rules: no camera, blocking, unlock, or exercise-verification code.
enum PushupCard: String, Codable, CaseIterable {
    case one = "1", two = "2", three = "3", skip = "SKIP"
}

enum PushupAction: String, Codable { case ready, draw, done, giveUp }

struct PushupCommand: Codable, Equatable {
    let gameID: UUID
    let revision: Int
    let action: PushupAction
}

struct PushupGame: Codable, Equatable {
    enum Phase: String, Codable { case preparing, playing, finished }
    let id: UUID
    private(set) var revision = 0
    private(set) var ready = [false, false]
    private(set) var phase: Phase = .preparing
    private(set) var turn = 0
    private(set) var card: PushupCard?
    private(set) var loser: Int?

    init(id: UUID = UUID()) { self.id = id }

    var isValid: Bool {
        guard revision >= 0, ready.count == 2, (0...1).contains(turn) else { return false }
        switch phase {
        case .preparing: return loser == nil && card == nil && !ready.allSatisfy { $0 }
        case .playing: return loser == nil && ready.allSatisfy { $0 }
        case .finished: return loser.map { (0...1).contains($0) } == true && ready.allSatisfy { $0 }
        }
    }

    // One shared phone owns the state. A turn can reveal only one card.
    // Ignore stale draw/done taps from a previously rendered turn.
    @discardableResult
    mutating func apply(_ command: PushupCommand, player: Int, draw: () -> PushupCard = { PushupCard.allCases.randomElement()! }) -> Bool {
        guard command.gameID == id, (0...1).contains(player), phase != .finished else { return false }
        switch command.action {
        case .ready:
            guard phase == .preparing, !ready[player] else { return false }
            ready[player] = true
            if ready.allSatisfy({ $0 }) { phase = .playing }
        case .draw:
            guard phase == .playing, player == turn, card == nil, command.revision == revision else { return false }
            card = draw()
        case .done:
            guard phase == .playing, player == turn, card != nil, command.revision == revision else { return false }
            card = nil
            turn = 1 - turn
        case .giveUp:
            guard phase == .playing else { return false }
            loser = player
            phase = .finished
        }
        revision += 1
        return true
    }
}
