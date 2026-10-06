import Foundation

// Pure game rules: one shared phone, no exercise verification or camera access.
enum PushupCard: String, Codable, CaseIterable {
    case one = "1", two = "2", three = "3", skip = "SKIP"
}

enum PushupAction: String, Codable { case ready, draw, done }

struct PushupCommand: Codable, Equatable {
    let gameID: UUID
    let revision: Int
    let action: PushupAction
}

struct PushupGame: Codable, Equatable {
    enum Phase: String, Codable { case preparing, playing, finished }
    static let totalRounds = 10

    let id: UUID
    let playerCount: Int
    private(set) var revision = 0
    private(set) var ready: [Bool]
    private(set) var phase: Phase = .preparing
    private(set) var turn = 0
    private(set) var round = 1
    private(set) var card: PushupCard?

    init(playerCount: Int = 2, id: UUID = UUID()) {
        precondition((2...4).contains(playerCount))
        self.id = id
        self.playerCount = playerCount
        ready = Array(repeating: false, count: playerCount)
    }

    var isValid: Bool {
        guard (2...4).contains(playerCount), ready.count == playerCount,
              (0..<playerCount).contains(turn), (1...Self.totalRounds).contains(round), revision >= 0 else { return false }
        switch phase {
        case .preparing: return card == nil && round == 1 && !ready.allSatisfy { $0 }
        case .playing: return ready.allSatisfy { $0 }
        case .finished: return ready.allSatisfy { $0 } && round == Self.totalRounds && card == nil && turn == 0
        }
    }

    // Revision protects against stale taps from the previous rendered turn.
    @discardableResult
    mutating func apply(_ command: PushupCommand, player: Int, draw: () -> PushupCard = { PushupCard.allCases.randomElement()! }) -> Bool {
        guard command.gameID == id, command.revision == revision,
              (0..<playerCount).contains(player), phase != .finished else { return false }
        switch command.action {
        case .ready:
            guard phase == .preparing, !ready[player] else { return false }
            ready[player] = true
            if ready.allSatisfy({ $0 }) { phase = .playing }
        case .draw:
            guard phase == .playing, player == turn, card == nil else { return false }
            card = draw()
        case .done:
            guard phase == .playing, player == turn, card != nil else { return false }
            card = nil
            if turn + 1 < playerCount {
                turn += 1
            } else {
                turn = 0
                if round == Self.totalRounds { phase = .finished }
                else { round += 1 }
            }
        }
        revision += 1
        return true
    }
}
