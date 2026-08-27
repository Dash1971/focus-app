import SwiftUI

struct CountdownTimerView: View {
    @StateObject private var timer = CountdownTimerModel()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(durationString(timer.remainingSeconds))
                .font(.system(size: 64, weight: .medium, design: .rounded))
                .monospacedDigit()
            if !timer.isRunning {
                Stepper("\(timer.durationSeconds / 60) minutes", value: $timer.durationSeconds, in: 60...14_400, step: 60)
                    .padding(.horizontal)
            }
            HStack {
                Button(timer.isRunning ? "Pause" : "Start") {
                    timer.isRunning ? timer.pause() : timer.start()
                }
                .buttonStyle(.borderedProminent)
                Button("Reset") { timer.reset() }.buttonStyle(.bordered)
            }
            Spacer()
        }
        .navigationTitle("Timer")
    }
}

struct IntervalTimerView: View {
    @StateObject private var timer = IntervalTimerModel()

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Text(timer.phase.rawValue)
                        .font(.headline)
                        .foregroundStyle(timer.phase == .rest ? .green : .indigo)
                    Text(durationString(timer.remainingSeconds))
                        .font(.system(size: 54, weight: .medium, design: .rounded))
                        .monospacedDigit()
                    Text("Round \(timer.round) of \(timer.configuration.rounds)")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            if !timer.isRunning {
                Section("Configuration") {
                    Stepper("Work: \(timer.configuration.workSeconds)s", value: $timer.configuration.workSeconds, in: 5...3600, step: 5)
                    Stepper("Rest: \(timer.configuration.restSeconds)s", value: $timer.configuration.restSeconds, in: 5...1800, step: 5)
                    Stepper("Rounds: \(timer.configuration.rounds)", value: $timer.configuration.rounds, in: 1...100)
                    Toggle("Automatically start next phase", isOn: $timer.configuration.autoAdvance)
                }
            }
            Section {
                Button(timer.isRunning ? "Stop" : "Start Interval Timer") {
                    timer.isRunning ? timer.stop() : timer.start()
                }
                if !timer.configuration.autoAdvance && !timer.isRunning {
                    Button("Next phase") { timer.advance() }
                }
            }
        }
        .navigationTitle("Interval Timer")
    }
}
