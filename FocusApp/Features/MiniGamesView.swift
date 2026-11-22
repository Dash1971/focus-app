import SwiftUI
import UIKit

private struct MiniGame: Identifiable {
    let id: String
    let title: String
}

private enum MiniGameCatalog {
    static let available = [
        MiniGame(id: "flappy-push-up", title: "Flappy Bird Push-Up"),
        MiniGame(id: "pushup-challenge", title: "Pushup Challenge")
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
                            if game.id == "pushup-challenge" {
                                PushupChallengeIcon().frame(width: 58, height: 58)
                            } else {
                                FlappyBirdIcon()
                                    .frame(width: 58, height: 58)
                            }
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

// The original 1280×853 image is untouched. At 64pt width its white
// content remains within the 58pt icon; only unused black margins overflow.
struct PushupChallengeIcon: View {
    var body: some View {
        Image("PushupFriends").resizable().scaledToFit()
            .frame(width: 64, height: 64 * 2 / 3)
            .frame(width: 58, height: 58)
            .background(.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Two white figures doing push-ups")
    }
}

private enum FlappyBirdArtwork {
    static func draw(context: inout GraphicsContext, center: CGPoint, size: CGFloat) {
        let bird = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
        context.fill(Path(ellipseIn: bird), with: .color(.white))
        let beak = CGRect(x: bird.maxX - size / 13, y: center.y - size / 9,
                          width: size * 9 / 26, height: size * 6 / 26)
        context.fill(Path(roundedRect: beak, cornerRadius: size * 2 / 26),
                     with: .color(Color(white: 0.45)))
    }
}

private struct FlappyBirdIcon: View {
    var body: some View {
        Canvas { context, size in
            FlappyBirdArtwork.draw(context: &context,
                                   center: CGPoint(x: size.width * 0.43, y: size.height / 2),
                                   size: min(size.width, size.height) * 0.63)
        }
        .accessibilityLabel("Flappy Bird")
    }
}

private struct FlappyPipe: Identifiable {
    let id = UUID()
    var x: CGFloat
    let gapY: CGFloat
    let gapHeight: CGFloat
    var counted = false
}

private struct FlappyBirdPushUpView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var activeSeconds: TimeInterval = 0
    @StateObject private var eyeTracker = FrontCameraController()
    @State private var birdY: CGFloat = 0
    @State private var birdX: CGFloat = 72
    @State private var pipes: [FlappyPipe] = []
    @State private var score = 0
    @State private var started = false
    @State private var gameOver = false
    @State private var lastFrame = Date()
    @State private var timeSincePipe: TimeInterval = 0

    private let birdSize: CGFloat = 26
    private let pipeWidth: CGFloat = 56
    private var difficulty: FlappyDifficulty { FlappyDifficulty(activeSeconds: activeSeconds) }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(
                minimumInterval: 1.0 / 60.0,
                paused: !started || gameOver || eyeTracker.eyePosition == nil || scenePhase != .active
            )) { timeline in
                ZStack {
                    Color.black
                    if eyeTracker.status == .tracking || eyeTracker.status == .lookingForFace {
                        FrontCameraPreview(session: eyeTracker.session)
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
                        Text("Level \(difficulty.level)")
                            .font(.caption).padding(6)
                            .background(Color.black.opacity(0.75), in: Capsule())
                        Spacer()
                    }

                    if cameraUnavailable {
                        cameraUnavailableView
                    } else if eyeTracker.status == .requestingPermission || eyeTracker.status == .starting {
                        ProgressView("Starting camera…")
                            .padding(22)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    } else if eyeTracker.eyePosition == nil {
                        gameMessage("Keep both eyes visible", detail: "Use the front camera in your natural push-up position.")
                    } else if !started || gameOver {
                        VStack(spacing: 10) {
                            Text(gameOver ? "Game Over" : "Ready")
                                .font(.title2.bold())
                            Text(gameOver ? "Tap to restart" : "Tap to start · move your eye-line up and down during a push-up. Looking up/down does not steer.")
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
                .onChange(of: eyeTracker.eyePosition) { _, position in
                    updateBird(from: position, in: geometry.size)
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
        .onChange(of: scenePhase) { _, phase in
            lastFrame = .now
            if phase == .active { eyeTracker.start() }
            else { eyeTracker.stop() }
        }
    }

    private var cameraUnavailable: Bool {
        [.denied, .unavailable, .failed].contains(eyeTracker.status)
    }

    @ViewBuilder
    private var cameraUnavailableView: some View {
        VStack(spacing: 12) {
            Text(eyeTracker.status == .denied ? "Camera access is off" : "Front camera unavailable")
                .font(.headline)
            Text("Eye-position detection is required to play. Pupils and gaze are not tracked.")
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
        if let sample = eyeTracker.eyePosition {
            let eye = previewPoint(sample, in: size)
            context.stroke(Path(ellipseIn: CGRect(x: eye.x - 6, y: eye.y - 6, width: 12, height: 12)),
                           with: .color(.white.opacity(0.65)), lineWidth: 1)
        }
        FlappyBirdArtwork.draw(context: &context, center: CGPoint(x: birdX, y: birdY), size: birdSize)

        for pipe in pipes {
            let topHeight = max(0, pipe.gapY - pipe.gapHeight / 2)
            let bottomY = min(size.height, pipe.gapY + pipe.gapHeight / 2)
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
        guard let sample = eyeTracker.eyePosition, !cameraUnavailable else { return }
        if !started || gameOver {
            eyeTracker.calibrateEyes()
            positionBesideEye(sample, in: size)
            pipes = []
            score = 0
            activeSeconds = 0
            timeSincePipe = 0
            gameOver = false
            started = true
            lastFrame = .now
        }
    }

    private func previewPoint(_ sample: FrontCameraController.EyePosition, in size: CGSize) -> CGPoint {
        func coordinate(_ value: CGFloat, horizontal: Bool) -> CGFloat {
            CGFloat(EyeTrackingPolicy.previewCoordinate(Double(value),
                imageWidth: Double(sample.imageSize.width), imageHeight: Double(sample.imageSize.height),
                viewWidth: Double(size.width), viewHeight: Double(size.height), horizontal: horizontal))
        }
        return CGPoint(x: coordinate(sample.point.x, horizontal: true), y: coordinate(sample.point.y, horizontal: false))
    }

    private func positionBesideEye(_ sample: FrontCameraController.EyePosition, in size: CGSize) {
        let eye = previewPoint(sample, in: size)
        let x = eye.x > 62 ? eye.x - 42 : eye.x + 42
        birdX = min(max(birdSize, x), max(birdSize, size.width - birdSize))
        birdY = min(max(birdSize, eye.y), max(birdSize, size.height - birdSize))
    }

    private func updateBird(from sample: FrontCameraController.EyePosition?, in size: CGSize) {
        guard !gameOver, let sample, size.height > 0 else { return }
        if !started { positionBesideEye(sample, in: size); return }
        // X stays fixed for the round; only eye-line height steers the bird.
        let eye = previewPoint(sample, in: size)
        birdY = min(max(birdSize, eye.y), max(birdSize, size.height - birdSize))
    }

    private func advance(from oldDate: Date, to newDate: Date, in size: CGSize) {
        guard started, !gameOver, eyeTracker.eyePosition != nil, scenePhase == .active, size.width > 0, size.height > 0 else { return }
        let elapsed = newDate.timeIntervalSince(lastFrame)
        let delta = min(0.05, max(0, elapsed > 0 ? elapsed : newDate.timeIntervalSince(oldDate)))
        let step = CGFloat(delta)
        lastFrame = newDate

        timeSincePipe += delta
        activeSeconds += delta

        for index in pipes.indices {
            pipes[index].x -= CGFloat(difficulty.speed) * step
            if !pipes[index].counted, pipes[index].x + pipeWidth < birdX {
                pipes[index].counted = true
                score += 1
            }
        }
        pipes.removeAll { $0.x + pipeWidth < -8 }

        if timeSincePipe >= difficulty.spawnInterval {
            let gapHeight = min(CGFloat(difficulty.gapHeight), size.height * 0.65)
            timeSincePipe = 0
            let lower = max(gapHeight / 2 + 30, size.height * 0.24)
            let upper = min(size.height - gapHeight / 2 - 30, size.height * 0.76)
            pipes.append(FlappyPipe(x: size.width + 12, gapY: CGFloat.random(in: lower...max(lower, upper)), gapHeight: gapHeight))
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
            let top = CGRect(x: pipe.x, y: 0, width: pipeWidth, height: pipe.gapY - pipe.gapHeight / 2)
            let bottomY = pipe.gapY + pipe.gapHeight / 2
            let bottom = CGRect(x: pipe.x, y: bottomY, width: pipeWidth, height: size.height - bottomY)
            if bird.intersects(top) || bird.intersects(bottom) { return true }
        }
        return false
    }
}
