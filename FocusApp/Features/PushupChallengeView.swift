import SwiftUI

// Players cooperate through ten rounds on one shared iPhone.
struct PushupChallengeView: View {
    @State private var game: PushupGame?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let game {
                    switch game.phase {
                    case .preparing: preparation(game)
                    case .playing: turn(game)
                    case .finished: result
                    }
                } else {
                    introduction
                }
            }.padding(24).frame(maxWidth: .infinity)
        }
        .background(Color.black)
        .navigationTitle("Pushup Challenge")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var introduction: some View {
        VStack(spacing: 20) {
            Text("Place the phone where everyone can reach it. Get into pushup position, then each tap Ready.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("Take turns drawing 1–3 or SKIP. Complete the card and tap Done. Everyone completes all ten rounds together.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("How many players?").font(.title2.weight(.semibold))
            ForEach(2...4, id: \.self) { count in
                Button("\(count) Players") { game = PushupGame(playerCount: count) }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func preparation(_ game: PushupGame) -> some View {
        VStack(spacing: 20) {
            Text("Ready to begin").font(.title2.weight(.semibold))
            ForEach(0..<game.playerCount, id: \.self) { player in
                Button(game.ready[player] ? "Player \(player + 1): Ready ✓" : "Player \(player + 1): Ready") {
                    perform(.ready, player: player)
                }
                .buttonStyle(.bordered)
                .disabled(game.ready[player])
            }
        }
    }

    private func turn(_ game: PushupGame) -> some View {
        VStack(spacing: 24) {
            Text("ROUND \(game.round) / \(PushupGame.totalRounds)")
                .font(.title2.weight(.semibold))
            Text("Player \(game.turn + 1)'s turn")
                .font(.title.weight(.semibold))
                .accessibilityAddTraits(.updatesFrequently)
            Button { perform(.draw, player: game.turn) } label: {
                Text(game.card?.rawValue ?? "")
                    .font(.system(size: 60, weight: .medium)).foregroundStyle(.white)
                    .frame(width: 190, height: 260)
                    .background(Color.black)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(game.card.map { "Revealed card: \($0.rawValue)" } ?? "Card stack. Tap to draw.")
            .disabled(game.card != nil)
            Text(instruction(for: game.card)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Done") { perform(.done, player: game.turn) }
                .buttonStyle(.bordered)
                .disabled(game.card == nil)
                .accessibilityHint("Complete Player \(game.turn + 1)'s turn")
        }
    }

    private var result: some View {
        VStack(spacing: 20) {
            Text("Challenge complete!").font(.largeTitle.bold())
            Text("All players completed 10 rounds together.").foregroundStyle(.secondary)
            Button("Play again") { game = nil }.buttonStyle(.bordered)
        }
    }

    private func instruction(for card: PushupCard?) -> String {
        guard let card else { return "Tap the card to draw." }
        if card == .skip { return "No pushups this turn. Press Done to pass." }
        return "Complete \(card.rawValue) \(card == .one ? "pushup" : "pushups"), then press Done."
    }

    private func perform(_ action: PushupAction, player: Int) {
        guard var game else { return }
        guard game.apply(PushupCommand(gameID: game.id, revision: game.revision, action: action), player: player) else { return }
        self.game = game
    }
}
