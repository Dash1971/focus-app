import SwiftUI
import UIKit

private struct MiniGame: Identifiable {
    let id: String
    let title: String
    let icon: String
}

private enum MiniGameCatalog {
    static let available = [
        MiniGame(id: "flappy-push-up", title: "Flappy Bird Push-Up", icon: "figure.strengthtraining.traditional"),
        MiniGame(id: "pushup-challenge", title: "Pushup Challenge", icon: "person.2")
    ]
}

struct MiniGamesView: View {
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(MiniGameCatalog.available) { game in
                    NavigationLink {
                        destination(for: game)
                    } label: {
                        VStack(alignment: .leading, spacing: 16) {
                            Image(systemName: game.icon)
                                .font(.system(size: 30, weight: .light))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(game.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            HStack {
                                Text("Play").font(.caption.weight(.semibold))
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
                        .background(Color(white: 0.09), in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("Mini Games")
    }

    @ViewBuilder
    private func destination(for game: MiniGame) -> some View {
        switch game.id {
        case "flappy-push-up": FlappyBirdPushUpView()
        case "pushup-challenge": PushupChallengeView()
        default: EmptyView()
        }
    }
}

private struct FlappyPipe: Identifiable {
    let id = UUID()
    var x: CGFloat
    let gapY: CGFloat
    var counted = false
}

private struct FlappyBirdPushUpView: View {
    @StateObject private var eyeTracker = EyeLevelCameraController()
    @State private var birdY: CGFloat = 0
    @State private var eyeBaseline: CGFloat?
    @State private var pipes: [FlappyPipe] = []
    @State private var score = 0
    @State private var started = false
    @State private var gameOver = false
    @State private var lastFrame = Date()
    @State private var timeSincePipe: TimeInterval = 0

    private let birdX: CGFloat = 72
    private let birdSize: CGFloat = 26
    private let pipeWidth: CGFloat = 56
    private let gapHeight: CGFloat = 158

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(
                minimumInterval: 1.0 / 60.0,
                paused: !started || gameOver || eyeTracker.eyeLevel == nil
            )) { timeline in
                ZStack {
                    Color.black
                    if eyeTracker.status == .tracking || eyeTracker.status == .lookingForEyes {
                        EyeCameraPreview(session: eyeTracker.session)
                            // Keep live camera pixels natural and fully visible.
                            .accessibilityLabel("Live front camera preview")
                    }
                    Canvas { context, size in
                        drawGame(context: &context, size: size)
                    }

                    VStack {
                        Text("\(score)")
                            .font(.system(size: 38, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .padding(10)
                            .background(Color.black.opacity(0.75), in: Capsule())
                            .padding(.top, 24)
                        Spacer()
                    }

                    if cameraUnavailable {
                        cameraUnavailableView
                    } else if eyeTracker.status == .requestingPermission || eyeTracker.status == .starting {
                        ProgressView("Starting camera…")
                            .padding(22)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    } else if eyeTracker.eyeLevel == nil {
                        gameMessage("Position your eyes in view", detail: "Use the front camera in your push-up position.")
                    } else if !started || gameOver {
                        VStack(spacing: 10) {
                            Text(gameOver ? "Game Over" : "Ready")
                                .font(.title2.bold())
                            Text(gameOver ? "Tap to restart" : "Tap to start · move your eye level up and down")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(22)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in startOrRestart(in: geometry.size) }
                )
                .onAppear { prepare(in: geometry.size) }
                .onChange(of: eyeTracker.eyeLevel) { _, eyeLevel in
                    updateBird(from: eyeLevel, in: geometry.size)
                }
                .onChange(of: timeline.date) { oldDate, newDate in
                    advance(from: oldDate, to: newDate, in: geometry.size)
                }
            }
        }
        .background(Color.black)
        .navigationTitle("Flappy Bird Push-Up")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { eyeTracker.start() }
        .onDisappear { eyeTracker.stop() }
    }

    private var cameraUnavailable: Bool {
        [.denied, .unavailable, .failed].contains(eyeTracker.status)
    }

    @ViewBuilder
    private var cameraUnavailableView: some View {
        VStack(spacing: 12) {
            Text(eyeTracker.status == .denied ? "Camera access is off" : "Front camera unavailable")
                .font(.headline)
            Text("Eye tracking is required to play.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if eyeTracker.status == .denied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .multilineTextAlignment(.center)
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func gameMessage(_ title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func drawGame(context: inout GraphicsContext, size: CGSize) {
        let birdRect = CGRect(
            x: birdX - birdSize / 2,
            y: birdY - birdSize / 2,
            width: birdSize,
            height: birdSize
        )
        context.fill(Path(ellipseIn: birdRect), with: .color(.white))
        let beak = CGRect(x: birdRect.maxX - 2, y: birdY - 3, width: 9, height: 6)
        context.fill(Path(roundedRect: beak, cornerRadius: 2), with: .color(Color(white: 0.45)))

        for pipe in pipes {
            let topHeight = max(0, pipe.gapY - gapHeight / 2)
            let bottomY = min(size.height, pipe.gapY + gapHeight / 2)
            let top = CGRect(x: pipe.x, y: 0, width: pipeWidth, height: topHeight)
            let bottom = CGRect(x: pipe.x, y: bottomY, width: pipeWidth, height: max(0, size.height - bottomY))
            context.fill(Path(roundedRect: top, cornerRadius: 8), with: .color(Color(white: 0.18)))
            context.fill(Path(roundedRect: bottom, cornerRadius: 8), with: .color(Color(white: 0.18)))
        }
    }

    private func prepare(in size: CGSize) {
        guard birdY == 0 else { return }
        birdY = size.height / 2
        lastFrame = .now
    }

    private func startOrRestart(in size: CGSize) {
        guard let eyeLevel = eyeTracker.eyeLevel, !cameraUnavailable else { return }
        if !started || gameOver {
            birdY = size.height / 2
            eyeBaseline = eyeLevel
            pipes = []
            score = 0
            timeSincePipe = 0
            gameOver = false
            started = true
            lastFrame = .now
        }
    }

    private func updateBird(from eyeLevel: CGFloat?, in size: CGSize) {
        guard started, !gameOver, let eyeLevel, let baseline = eyeBaseline, size.height > 0 else { return }
        let controlled = min(0.9, max(0.1, 0.5 + (eyeLevel - baseline) * 2.7))
        birdY = controlled * size.height
    }

    private func advance(from oldDate: Date, to newDate: Date, in size: CGSize) {
        guard started, !gameOver, size.width > 0, size.height > 0 else { return }
        let elapsed = newDate.timeIntervalSince(lastFrame)
        let delta = min(0.05, max(0, elapsed > 0 ? elapsed : newDate.timeIntervalSince(oldDate)))
        let step = CGFloat(delta)
        lastFrame = newDate

        timeSincePipe += delta

        for index in pipes.indices {
            pipes[index].x -= 132 * step
            if !pipes[index].counted, pipes[index].x + pipeWidth < birdX {
                pipes[index].counted = true
                score += 1
            }
        }
        pipes.removeAll { $0.x + pipeWidth < -8 }

        if timeSincePipe >= 1.75 {
            timeSincePipe = 0
            let lower = max(gapHeight / 2 + 30, size.height * 0.24)
            let upper = min(size.height - gapHeight / 2 - 30, size.height * 0.76)
            pipes.append(FlappyPipe(x: size.width + 12, gapY: CGFloat.random(in: lower...max(lower, upper))))
        }

        if collided(in: size) { gameOver = true }
    }

    private func collided(in size: CGSize) -> Bool {
        let bird = CGRect(
            x: birdX - birdSize / 2,
            y: birdY - birdSize / 2,
            width: birdSize,
            height: birdSize
        )
        if bird.minY <= 0 || bird.maxY >= size.height { return true }

        for pipe in pipes {
            let top = CGRect(x: pipe.x, y: 0, width: pipeWidth, height: pipe.gapY - gapHeight / 2)
            let bottomY = pipe.gapY + gapHeight / 2
            let bottom = CGRect(x: pipe.x, y: bottomY, width: pipeWidth, height: size.height - bottomY)
            if bird.intersects(top) || bird.intersects(bottom) { return true }
        }
        return false
    }
}
