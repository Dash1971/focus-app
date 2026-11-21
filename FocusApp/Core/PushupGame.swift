import Foundation

// Pure game rules: one shared phone, no exercise verification or camera access.
enum PushupCard: String, Codable, CaseIterable {
    case one = "1", two = "2", three = "3", skip = "SKIP"
    var pushups: Int { Int(rawValue) ?? 0 }
}

enum PushupRounds: String, Codable, CaseIterable, Identifiable {
    case five = "5 Rounds", ten = "10 Rounds", endless = "Endless"
    var id: String { rawValue }
    var limit: Int? {
        switch self { case .five: 5; case .ten: 10; case .endless: nil }
    }
}

enum PushupAction: String, Codable { case ready, draw, done, finish }

struct PushupCommand: Codable, Equatable {
    let gameID: UUID
    let revision: Int
    let action: PushupAction
}

struct PushupGame: Codable, Equatable {
    enum Phase: String, Codable { case preparing, playing, finished }
    let id: UUID
    let playerCount: Int
    let rounds: PushupRounds
    private(set) var revision = 0
    private(set) var ready: [Bool]
    private(set) var phase: Phase = .preparing
    private(set) var turn = 0
    private(set) var round = 1
    private(set) var card: PushupCard?
    // One row per played round. nil = turn not completed; 0 = confirmed SKIP.
    private(set) var roundPushups: [[Int?]] = []

    init(playerCount: Int = 2, rounds: PushupRounds = .ten, id: UUID = UUID()) {
        precondition((2...4).contains(playerCount))
        self.id = id
        self.playerCount = playerCount
        self.rounds = rounds
        ready = Array(repeating: false, count: playerCount)
    }

    var playerTotals: [Int] {
        (0..<playerCount).map { player in roundPushups.reduce(0) { $0 + ($1[player] ?? 0) } }
    }
    var totalPushups: Int { playerTotals.reduce(0, +) }
    var completedRounds: Int { roundPushups.filter { $0.allSatisfy { $0 != nil } }.count }

    var isValid: Bool {
        guard (2...4).contains(playerCount), ready.count == playerCount,
              (0..<playerCount).contains(turn), round >= 1, revision >= 0,
              round <= (rounds.limit ?? Int.max), roundPushups.count <= round,
              roundPushups.allSatisfy({ row in
                  row.count == playerCount && row.allSatisfy { $0 == nil || (0...3).contains($0!) }
              }) else { return false }
        switch phase {
        case .preparing: return card == nil && round == 1 && roundPushups.isEmpty && !ready.allSatisfy { $0 }
        case .playing: return ready.allSatisfy { $0 }
        case .finished:
            return ready.allSatisfy { $0 } && card == nil
                && (rounds == .endless || (round == rounds.limit && completedRounds == rounds.limit && turn == 0))
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
            guard phase == .playing, player == turn, let card else { return false }
            if roundPushups.count < round { roundPushups.append(Array(repeating: nil, count: playerCount)) }
            roundPushups[round - 1][player] = card.pushups
            self.card = nil
            if turn + 1 < playerCount { turn += 1 }
            else {
                turn = 0
                if round == rounds.limit { phase = .finished }
                else { round += 1 }
            }
        case .finish:
            guard rounds == .endless, phase == .playing, player == turn else { return false }
            card = nil // A drawn but unconfirmed card is never recorded as exercise.
            phase = .finished
        }
        revision += 1
        return true
    }
}
