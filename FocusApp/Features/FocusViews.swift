import SwiftUI
import FamilyControls

struct StartFocusView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 30
    @State private var challenge = Challenge()
    @State private var selection = FamilyActivitySelection()
    @State private var showingPicker = false
    @State private var useEndTime = false
    @State private var endTime = Date().addingTimeInterval(30 * 60)

    var body: some View {
        Form {
            Section("Duration") {
                Toggle("Block until a specific time", isOn: $useEndTime)
                if useEndTime {
                    DatePicker("Blocked until", selection: $endTime, in: Date().addingTimeInterval(60)..., displayedComponents: [.date, .hourAndMinute])
                } else {
                    Stepper("\(minutes) minutes", value: $minutes, in: 1...240, step: 5)
                }
            }
            Section("Apps to block") {
                Button(selection.isEmpty ? "Choose apps, categories, or websites" : "Change selection") { showingPicker = true }
                if selection.isEmpty { Text("Uses your main Block Apps selection if left empty.").font(.footnote).foregroundStyle(.secondary) }
            }
            ChallengeEditor(challenge: $challenge)
            Section {
                Button("Start Focus Session") {
                    let chosen = selection.isEmpty ? nil : selection
                    if useEndTime { model.beginFocus(until: endTime, challenge: challenge, selection: chosen) }
                    else { model.beginFocus(minutes: minutes, challenge: challenge, selection: chosen) }
                    if model.activeSession != nil { dismiss() }
                }
                .frame(maxWidth: .infinity)
                .font(.headline)
            }
        }
        .navigationTitle("Start Focus")
        .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
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
    @EnvironmentObject private var model: AppModel
    @Binding var challenge: Challenge

    var body: some View {
        Section("Unlock challenge") {
            Picker("Challenge", selection: $challenge.kind) {
                ForEach(ChallengeKind.allCases) { kind in Text(kind.title).tag(kind) }
            }
            if ![.none, .math, .puzzle, .question, .custom].contains(challenge.kind) {
                Stepper("Requirement: \(challenge.amount)", value: $challenge.amount, in: 1...100)
            }
            if [.bicepCurls, .shoulderPresses].contains(challenge.kind) {
                Stepper("Weight: \(challenge.weightKilograms.formatted()) kg", value: $challenge.weightKilograms, in: 0.5...100, step: 0.5)
            }
            if [.custom, .question].contains(challenge.kind) {
                TextField("What must be completed?", text: $challenge.customText, axis: .vertical)
            }
            if challenge.kind == .question {
                TextField("Correct answer", text: $challenge.expectedAnswer)
            }
            if challenge.kind == .custom && !challenge.customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Save to challenge library") { model.saveCustomChallenge(challenge) }
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
                    } else if challenge.kind == .puzzle {
                        Text("Continue the pattern: 2, 4, 6, 8, …").font(.title3.bold())
                        TextField("Answer", text: $answer).keyboardType(.numberPad)
                    } else if challenge.kind == .question {
                        Text(challenge.customText).font(.title3.bold())
                        TextField("Answer", text: $answer)
                    } else {
                        Text(challenge.instruction).font(.title3.bold())
                        Toggle("I completed this honestly", isOn: $confirmation)
                    }
                }
                Button("Complete and Unlock") {
                    model.completeChallengeAndUnlock()
                    dismiss()
                }
                .disabled(!isChallengeValid(challenge, answer: answer, confirmation: confirmation, mathAnswer: first + second))
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
                    } else if schedule.challenge.kind == .puzzle {
                        Text("Continue the pattern: 2, 4, 6, 8, …").font(.title3.bold())
                        TextField("Answer", text: $answer).keyboardType(.numberPad)
                    } else if schedule.challenge.kind == .question {
                        Text(schedule.challenge.customText).font(.title3.bold())
                        TextField("Answer", text: $answer)
                    } else {
                        Text(schedule.challenge.instruction).font(.title3.bold())
                        Toggle("I completed this honestly", isOn: $confirmation)
                    }
                }
                Button("Complete and Disable Schedule") {
                    model.unlockSchedule(schedule, completedChallenge: true, emergency: false)
                    dismiss()
                }
                .disabled(!isChallengeValid(schedule.challenge, answer: answer, confirmation: confirmation, mathAnswer: first + second))
            }
            .navigationTitle("Earn the Unlock")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

func durationString(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

private func isChallengeValid(_ challenge: Challenge, answer: String, confirmation: Bool, mathAnswer: Int) -> Bool {
    switch challenge.kind {
    case .math: Int(answer) == mathAnswer
    case .puzzle: Int(answer) == 10
    case .question: !challenge.expectedAnswer.isEmpty && answer.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(challenge.expectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    default: confirmation
    }
}

private extension FamilyActivitySelection {
    var isEmpty: Bool { applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty }
}
