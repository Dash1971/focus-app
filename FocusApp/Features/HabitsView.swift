import SwiftUI

struct HabitsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var anchor = Date()
    @State private var editing: Habit?
    private var period: HabitPeriod { model.life.habitPeriod }
    private var days: [Date] { period.days(containing: anchor) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Viewing period", selection: Binding(get: { period }, set: { value in model.editLife { $0.habitPeriod = value } })) {
                    ForEach(HabitPeriod.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }.pickerStyle(.segmented)
                Toggle("Show daily history", isOn: Binding(get: { model.life.showHabitHistory }, set: { value in model.editLife { $0.showHabitHistory = value } }))
                HStack {
                    Button { move(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous period")
                    Spacer()
                    VStack {
                        if let first = days.first { Text(first, format: .dateTime.month().day().year()) }
                        if period != .day, let last = days.last { Text("to " + last.formatted(.dateTime.month().day().year())).foregroundStyle(.secondary) }
                    }.font(.subheadline)
                    Spacer()
                    Button { move(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next period")
                }
                Button("Current \(period.rawValue)") { anchor = .now }
                if model.life.habits.isEmpty {
                    ContentUnavailableView("Build a small habit", systemImage: "checkmark.circle", description: Text("Add a habit, then mark the days you complete it."))
                }
                ForEach(model.life.habits) { habit in
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(habit.name).font(.headline)
                            Spacer()
                            Button { editing = habit } label: { Image(systemName: "pencil") }.accessibilityLabel("Edit \(habit.name)")
                        }
                        let completed = days.filter { habit.completedDays.contains(TimePolicy.dayKey($0)) }.count
                        Text("\(completed) of \(days.count) days completed").font(.subheadline).foregroundStyle(.secondary)
                        Button {
                            model.toggleHabit(habit.id, date: .now)
                        } label: {
                            Label(habit.completedDays.contains(TimePolicy.dayKey(.now)) ? "Completed today" : "Mark today complete", systemImage: habit.completedDays.contains(TimePolicy.dayKey(.now)) ? "checkmark.circle.fill" : "circle")
                        }.buttonStyle(.bordered)
                        if model.life.showHabitHistory {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                                ForEach(days, id: \.self) { date in
                                    let done = habit.completedDays.contains(TimePolicy.dayKey(date))
                                    Button { model.toggleHabit(habit.id, date: date) } label: {
                                        VStack(spacing: 2) {
                                            if Calendar.current.component(.day, from: date) == 1 { Text(date, format: .dateTime.month(.abbreviated)).font(.system(size: 8)) }
                                            Text("\(Calendar.current.component(.day, from: date))").font(.caption.monospacedDigit())
                                            Image(systemName: done ? "checkmark" : "minus").font(.system(size: 8))
                                        }.frame(maxWidth: .infinity, minHeight: 44)
                                            .background(done ? Color.white.opacity(0.22) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                                    }.buttonStyle(.plain)
                                        .disabled(Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: .now))
                                        .accessibilityLabel(date.formatted(date: .complete, time: .omitted) + (done ? ", completed" : ", not completed"))
                                }
                            }
                        }
                    }.card()
                }
            }.padding()
        }
        .background(Color.black).navigationTitle("Habits")
        .disabled(!model.lifeReady)
        .toolbar { Button { editing = Habit(name: "") } label: { Image(systemName: "plus") }.accessibilityLabel("Add habit") }
        .sheet(item: $editing) { HabitEditor(habit: $0).environmentObject(model) }
    }

    private func move(_ amount: Int) {
        guard let start = days.first else { return }
        anchor = Calendar.current.date(byAdding: period.component, value: amount, to: start) ?? anchor
    }
}

private struct HabitEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var habit: Habit
    @State private var confirmingDelete = false
    private var existing: Bool { model.life.habits.contains { $0.id == habit.id } }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Habit name", text: $habit.name)
                if existing { Button("Delete habit and history", role: .destructive) { confirmingDelete = true } }
            }.navigationTitle(existing ? "Edit habit" : "New habit")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        habit.name = habit.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if model.editLife({ state in
                            if let index = state.habits.firstIndex(where: { $0.id == habit.id }) { state.habits[index].name = habit.name }
                            else { state.habits.append(habit) }
                        }) { dismiss() }
                    }.disabled(habit.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
                .confirmationDialog("Delete this habit and its history?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("Delete habit", role: .destructive) { if model.editLife({ $0.habits.removeAll { $0.id == habit.id } }) { dismiss() } }
                }
        }
    }
}
