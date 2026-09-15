import SwiftUI

// Two people share this single game state on one iPhone. No camera, networking,
// motion tracking, or dependency on Restrictions/AppModel is needed.
struct PushupChallengeView: View {
    @State private var game = PushupGame()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                switch game.phase {
                case .preparing: preparation
                case .playing: turn
                case .finished: result
                }
            }.padding(24).frame(maxWidth: .infinity)
        }
        .background(Color.black)
        .navigationTitle("Pushup Challenge")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var preparation: some View {
        VStack(spacing: 20) {
            Text("Two players. One iPhone.").font(.title2.weight(.semibold))
            Text("Place the phone where you can both reach it. Get into pushup position, then each tap Ready.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("Take turns drawing 1–3 or SKIP. Complete the card and tap Done. The player who gives up on their turn loses.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            ForEach(0..<2, id: \.self) { player in
                Button(game.ready[player] ? "Player \(player + 1) is ready" : "Player \(player + 1): Ready") {
                    perform(.ready, player: player)
                }
                .buttonStyle(.bordered)
                .disabled(game.ready[player])
            }
        }
    }

    private var turn: some View {
        VStack(spacing: 24) {
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
            Text(instruction).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Done") { perform(.done, player: game.turn) }
                .buttonStyle(.bordered)
                .disabled(game.card == nil)
                .accessibilityHint("Complete Player \(game.turn + 1)'s turn and pass to Player \(2 - game.turn)")
            Button("Give Up") { perform(.giveUp, player: game.turn) }
                .buttonStyle(.bordered)
                .accessibilityHint("Player \(game.turn + 1) loses this game")
        }
    }

    @ViewBuilder
    private var result: some View {
        if let loser = game.loser {
            Text("Player \(2 - loser) wins").font(.largeTitle.bold())
            Text("Player \(loser + 1) gave up.").foregroundStyle(.secondary)
            Button("Play again") { game = PushupGame() }.buttonStyle(.bordered)
        }
    }

    private var instruction: String {
        guard let card = game.card else { return "Tap the card to draw." }
        if card == .skip { return "No pushups this turn. Press Done to pass." }
        return "Complete \(card.rawValue) \(card == .one ? "pushup" : "pushups"), then press Done."
    }

    private func perform(_ action: PushupAction, player: Int) {
        game.apply(PushupCommand(gameID: game.id, revision: game.revision, action: action), player: player)
    }
}
