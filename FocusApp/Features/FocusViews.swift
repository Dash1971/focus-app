import SwiftUI

struct StartFocusView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 30
    @State private var challenge = Challenge()

    var body: some View {
        Form {
            Section("Duration") {
                Stepper("\(minutes) minutes", value: $minutes, in: 1...240, step: 5)
            }
            ChallengeEditor(challenge: $challenge)
            Section {
                Button("Start Focus Session") {
                    model.beginFocus(minutes: minutes, challenge: challenge)
                    if model.activeSession != nil { dismiss() }
                }
                .frame(maxWidth: .infinity)
                .font(.headline)
            }
        }
        .navigationTitle("Start Focus")
    }
}

struct ActiveSessionCard: View {
    @EnvironmentObject private var model: AppModel
    let session: ActiveFocusSession
    @State private var showingUnlock = false
    @State private var showingEmergency = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(.indigo)
            Text("FOCUS ACTIVE").font(.headline)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(durationString(max(0, Int(session.endsAt.timeIntervalSince(context.date)))))
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            Text("Ends \(session.endsAt.formatted(date: .omitted, time: .shortened))")
                .foregroundStyle(.secondary)
            if session.challenge.kind != .none {
                Button("Unlock with challenge") { showingUnlock = true }
                    .buttonStyle(.bordered)
            }
            Button("Emergency Unlock", role: .destructive) { showingEmergency = true }
                .font(.footnote)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.indigo.opacity(0.09), in: RoundedRectangle(cornerRadius: 22))
        .sheet(isPresented: $showingUnlock) { ChallengeCompletionView(challenge: session.challenge) }
        .confirmationDialog("Emergency Unlock", isPresented: $showingEmergency, titleVisibility: .visible) {
            Button("Unlock all selected apps", role: .destructive) { model.emergencyUnlock() }
            Button("Keep focusing", role: .cancel) {}
        } message: {
            Text("This ends the current session and will be recorded as an emergency unlock.")
        }
    }
}

struct ActiveScheduleCard: View {
    @EnvironmentObject private var model: AppModel
    let schedule: BlockSchedule
    @State private var showingChallenge = false
    @State private var showingEmergency = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock").font(.largeTitle).foregroundStyle(.indigo)
            Text("\(schedule.name.uppercased()) ACTIVE").font(.headline)
            Text("Blocked until \(schedule.endDate.formatted(date: .omitted, time: .shortened))")
                .foregroundStyle(.secondary)
            if schedule.challenge.kind != .none {
                Button("Unlock with challenge") { showingChallenge = true }.buttonStyle(.bordered)
            }
            Button("Emergency Unlock", role: .destructive) { showingEmergency = true }.font(.footnote)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.indigo.opacity(0.09), in: RoundedRectangle(cornerRadius: 22))
        .sheet(isPresented: $showingChallenge) {
            ScheduleChallengeCompletionView(schedule: schedule)
        }
        .confirmationDialog("Emergency Unlock", isPresented: $showingEmergency, titleVisibility: .visible) {
            Button("Disable this schedule", role: .destructive) {
                model.unlockSchedule(schedule, completedChallenge: false, emergency: true)
            }
            Button("Keep schedule active", role: .cancel) {}
        }
    }
}

struct ChallengeEditor: View {
    @Binding var challenge: Challenge

    var body: some View {
        Section("Unlock challenge") {
            Picker("Challenge", selection: $challenge.kind) {
                ForEach(ChallengeKind.allCases) { kind in Text(kind.title).tag(kind) }
            }
            if ![.none, .math, .custom].contains(challenge.kind) {
                Stepper("Requirement: \(challenge.amount)", value: $challenge.amount, in: 1...100)
            }
            if challenge.kind == .custom {
                TextField("What must be completed?", text: $challenge.customText, axis: .vertical)
            }
            if challenge.kind != .none {
                Text(challenge.instruction).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

struct ChallengeCompletionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let challenge: Challenge
    @State private var answer = ""
    @State private var confirmation = false
    @State private var first = Int.random(in: 12...49)
    @State private var second = Int.random(in: 3...19)

    var body: some View {
        NavigationStack {
            Form {
                Section("Challenge") {
                    if challenge.kind == .math {
                        Text("\(first) + \(second) = ?").font(.title.bold())
                        TextField("Answer", text: $answer).keyboardType(.numberPad)
                    } else {
                        Text(challenge.instruction).font(.title3.bold())
                        Toggle("I completed this honestly", isOn: $confirmation)
                    }
                }
                Button("Complete and Unlock") {
                    model.completeChallengeAndUnlock()
                    dismiss()
                }
                .disabled(challenge.kind == .math ? Int(answer) != first + second : !confirmation)
            }
            .navigationTitle("Earn the Unlock")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct ScheduleChallengeCompletionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let schedule: BlockSchedule
    @State private var answer = ""
    @State private var confirmation = false
    @State private var first = Int.random(in: 12...49)
    @State private var second = Int.random(in: 3...19)

    var body: some View {
        NavigationStack {
            Form {
                Section("Challenge") {
                    if schedule.challenge.kind == .math {
                        Text("\(first) + \(second) = ?").font(.title.bold())
                        TextField("Answer", text: $answer).keyboardType(.numberPad)
                    } else {
                        Text(schedule.challenge.instruction).font(.title3.bold())
                        Toggle("I completed this honestly", isOn: $confirmation)
                    }
                }
                Button("Complete and Disable Schedule") {
                    model.unlockSchedule(schedule, completedChallenge: true, emergency: false)
                    dismiss()
                }
                .disabled(schedule.challenge.kind == .math ? Int(answer) != first + second : !confirmation)
            }
            .navigationTitle("Earn the Unlock")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

func durationString(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}
