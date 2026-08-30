import SwiftUI

struct ProgressViewScreen: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section("Today") {
                LabeledContent("Focus time", value: "\(model.focusMinutesToday) minutes")
                LabeledContent("Sessions completed", value: "\(model.sessionsToday)")
                LabeledContent("Selected distractions", value: "\(model.selectedItemCount)")
            }
            Section("This week") {
                LabeledContent("Focus time", value: "\(model.focusMinutesThisWeek) minutes")
                LabeledContent("Sessions completed", value: "\(model.sessionsThisWeek)")
            }
            Section("Saved custom challenges") {
                if model.customChallenges.isEmpty { Text("Save a custom challenge while configuring a block.").foregroundStyle(.secondary) }
                ForEach(Array(model.customChallenges.enumerated()), id: \.offset) { _, challenge in Text(challenge.customText) }
                .onDelete(perform: model.deleteCustomChallenges)
            }
            Section("All time") {
                LabeledContent("Challenges completed", value: "\(model.challengesCompleted)")
                LabeledContent("Emergency unlocks", value: "\(model.emergencyUnlocks)")
                LabeledContent("Completed sessions", value: "\(model.records.filter(\.completed).count)")
            }
            Section("Recent sessions") {
                if model.records.isEmpty {
                    Text("Completed focus sessions will appear here.").foregroundStyle(.secondary)
                }
                ForEach(model.records.sorted(by: { $0.startedAt > $1.startedAt }).prefix(20)) { record in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                            Text(record.emergencyUnlock ? "Emergency unlock" : (record.completed ? "Completed" : "Ended early"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(record.displayedMinutes)m")
                    }
                }
            }
        }
        .navigationTitle("Progress")
    }
}
