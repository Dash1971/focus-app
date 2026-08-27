import SwiftUI

struct SchedulesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editingSchedule: BlockSchedule?

    var body: some View {
        List {
            if model.schedules.isEmpty {
                ContentUnavailableView("No schedules", systemImage: "calendar.badge.plus", description: Text("Add a study, sleep, or custom blocking schedule."))
            }
            ForEach(model.schedules) { schedule in
                Button { editingSchedule = schedule } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(schedule.name).font(.headline)
                            Text("\(format(minutes: schedule.startMinutes)) – \(format(minutes: schedule.endMinutes))")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { schedule.enabled },
                            set: { model.setScheduleEnabled(schedule, enabled: $0) }
                        ))
                        .labelsHidden()
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: model.deleteSchedules)
        }
        .navigationTitle("Schedules")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editingSchedule = BlockSchedule() } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editingSchedule) { schedule in ScheduleEditor(schedule: schedule) }
    }
}

struct ScheduleEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var schedule: BlockSchedule

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule") {
                    TextField("Name", text: $schedule.name)
                    DatePicker("Starts", selection: Binding(
                        get: { date(minutes: schedule.startMinutes) },
                        set: { schedule.startMinutes = minutes(date: $0) }
                    ), displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: Binding(
                        get: { date(minutes: schedule.endMinutes) },
                        set: { schedule.endMinutes = minutes(date: $0) }
                    ), displayedComponents: .hourAndMinute)
                    Toggle("Enabled", isOn: $schedule.enabled)
                }
                Section("Days") {
                    HStack {
                        ForEach(Array(zip([1,2,3,4,5,6,7], ["S","M","T","W","T","F","S"])), id: \.0) { day, symbol in
                            Button(symbol) {
                                if schedule.weekdays.contains(day) { schedule.weekdays.remove(day) }
                                else { schedule.weekdays.insert(day) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(schedule.weekdays.contains(day) ? .indigo : .gray.opacity(0.35))
                        }
                    }
                }
                ChallengeEditor(challenge: $schedule.challenge)
            }
            .navigationTitle("Block Schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { model.saveSchedule(schedule); dismiss() }
                        .disabled(schedule.name.trimmingCharacters(in: .whitespaces).isEmpty || schedule.weekdays.isEmpty)
                }
            }
        }
    }
}

private func date(minutes: Int) -> Date {
    Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(minutes * 60))
}

private func minutes(date: Date) -> Int {
    let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
    return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
}

private func format(minutes: Int) -> String {
    date(minutes: minutes).formatted(date: .omitted, time: .shortened)
}
