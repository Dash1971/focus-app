import SwiftUI
import Charts

// Players cooperate on one shared iPhone. Totals come only from confirmed turns.
struct PushupChallengeView: View {
    @State private var game: PushupGame?
    @State private var rounds: PushupRounds = .ten
    @State private var confirmingFinish = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let game {
                    switch game.phase {
                    case .preparing: preparation(game)
                    case .playing: turn(game)
                    case .finished: result(game)
                    }
                } else {
                    introduction
                }
            }.padding(24).frame(maxWidth: .infinity)
        }
        .background(Color.black)
        .navigationTitle("Pushup Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Finish the challenge?", isPresented: $confirmingFinish, titleVisibility: .visible) {
            Button("Finish game") { if let game { perform(.finish, player: game.turn) } }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("Only turns confirmed with Done will appear in the summary. An unfinished card will not count.")
        }
    }

    private var introduction: some View {
        VStack(spacing: 20) {
            Text("Place the phone where everyone can reach it. Get into pushup position, then each tap Ready.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("Take turns drawing 1–3 or SKIP. Complete the card and tap Done. Choose 5 rounds, 10 rounds or keep going in Endless mode.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Picker("Rounds", selection: $rounds) {
                ForEach(PushupRounds.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            Text("How many players?").font(.title2.weight(.semibold))
            ForEach(2...4, id: \.self) { count in
                Button("\(count) Players") { game = PushupGame(playerCount: count, rounds: rounds) }
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
            Text(game.rounds.limit.map { "ROUND \(game.round) / \($0)" } ?? "ROUND \(game.round) · ENDLESS")
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
            if game.rounds == .endless {
                Button("Finish game") { confirmingFinish = true }.buttonStyle(.bordered)
            }
        }
    }

    private func result(_ game: PushupGame) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Challenge complete!").font(.largeTitle.bold())
            Text("\(game.completedRounds) complete rounds · \(game.rounds.rawValue)").foregroundStyle(.secondary)
            Text("All players: \(game.totalPushups) pushups").font(.title2.bold())
            Chart {
                ForEach(0..<game.playerCount, id: \.self) { player in
                    BarMark(x: .value("Pushups", game.playerTotals[player]),
                            y: .value("Player", "Player \(player + 1)"))
                        .foregroundStyle(Color.gray)
                        .annotation(position: .trailing) { Text("\(game.playerTotals[player])").font(.caption) }
                        .accessibilityLabel("Player \(player + 1)")
                        .accessibilityValue("\(game.playerTotals[player]) pushups")
                }
            }
            .chartXScale(domain: 0...max(1, game.playerTotals.max() ?? 0))
            .chartXAxisLabel("Total pushups")
            .frame(height: CGFloat(game.playerCount * 50 + 40))
            ForEach(0..<game.playerCount, id: \.self) { player in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Player \(player + 1) — \(game.playerTotals[player]) total").font(.headline)
                    ForEach(game.roundPushups.indices, id: \.self) { index in
                        HStack {
                            Text("Round \(index + 1)")
                            Spacer()
                            Text(game.roundPushups[index][player].map { "\($0)" } ?? "Not completed")
                                .monospacedDigit()
                        }.font(.subheadline)
                    }
                    if game.roundPushups.isEmpty { Text("No completed turns.").foregroundStyle(.secondary) }
                }.card()
            }
            Text("Recorded from cards confirmed with Done; SKIP counts as 0. Unfinished turns do not count.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Play again") { self.game = nil }.buttonStyle(.bordered)
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
