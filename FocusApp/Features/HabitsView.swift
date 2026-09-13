import SwiftUI

private extension HabitPeriod {
    var displayName: String {
        switch self {
        case .day: "Daily"
        case .week: "Weekly"
        case .month: "Month"
        case .year: "Yearly"
        }
    }
}

struct HabitsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var anchor = Date()
    @State private var editing: Habit?

    private var period: HabitPeriod { model.life.habitPeriod }
    private var days: [Date] { period.days(containing: anchor) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                viewSelector
                periodNavigator

                if model.life.habits.isEmpty {
                    ContentUnavailableView(
                        "Build a small habit",
                        systemImage: "checkmark.circle",
                        description: Text("Tap + to add your first habit.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    ForEach(model.life.habits) { habit in
                        HabitTrackerCard(
                            habit: habit,
                            period: period,
                            days: days,
                            onToggle: { model.toggleHabit(habit.id, date: $0) },
                            onEdit: { editing = habit }
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("Habits")
        .disabled(!model.lifeReady)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = Habit(name: "") } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add habit")
            }
        }
        .sheet(item: $editing) {
            HabitEditor(habit: $0).environmentObject(model)
        }
    }

    private var viewSelector: some View {
        Menu {
            ForEach(HabitPeriod.allCases) { option in
                Button {
                    model.editLife { $0.habitPeriod = option }
                    anchor = .now
                } label: {
                    if option == period {
                        Label(option.displayName, systemImage: "checkmark")
                    } else {
                        Text(option.displayName)
                    }
                }
            }
        } label: {
            HStack {
                Text(period.displayName).font(.headline)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Color(white: 0.09), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Habit view, \(period.displayName)")
    }

    private var periodNavigator: some View {
        HStack(spacing: 16) {
            Button { move(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous \(period.displayName.lowercased())")
            Spacer()
            Button { anchor = .now } label: {
                Text(periodLabel)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Return to the current period")
            Spacer()
            Button { move(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Next \(period.displayName.lowercased())")
        }
        .padding(.horizontal, 4)
    }

    private var periodLabel: String {
        guard let first = days.first else { return "Current" }
        switch period {
        case .day:
            return first.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        case .week:
            guard let last = days.last else { return "This week" }
            return first.formatted(.dateTime.month(.abbreviated).day())
                + " – " + last.formatted(.dateTime.month(.abbreviated).day())
        case .month:
            return first.formatted(.dateTime.month(.wide).year())
        case .year:
            return first.formatted(.dateTime.year())
        }
    }

    private func move(_ amount: Int) {
        guard let start = days.first else { return }
        anchor = Calendar.current.date(byAdding: period.component, value: amount, to: start) ?? anchor
    }
}

private struct HabitTrackerCard: View {
    let habit: Habit
    let period: HabitPeriod
    let days: [Date]
    let onToggle: (Date) -> Void
    let onEdit: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(habit.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button(action: onEdit) { Image(systemName: "ellipsis") }
                    .accessibilityLabel("Edit \(habit.name)")
            }

            switch period {
            case .day: dailyGrid
            case .week: weeklyGrid
            case .month: monthlyGrid
            case .year: yearlyGrid
            }
        }
        .card()
    }

    private var dailyGrid: some View {
        Group {
            if let date = days.first {
                completionButton(for: date) {
                    VStack(spacing: 12) {
                        Image(systemName: isDone(date) ? "checkmark" : "circle")
                            .font(.system(size: 38, weight: .light))
                        Text(isDone(date) ? "Complete" : "Tap to complete")
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity, minHeight: 132)
                    .background(cellColor(for: date), in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(isDone(date) ? 0 : 0.12))
                    }
                }
            }
        }
    }

    private var weeklyGrid: some View {
        HStack(spacing: 7) {
            ForEach(days, id: \.self) { date in
                VStack(spacing: 7) {
                    Text(date, format: .dateTime.weekday(.narrow))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    completionButton(for: date) {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(cellColor(for: date))
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if isDone(date) {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.black)
                                }
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color.white.opacity(isDone(date) ? 0 : 0.12))
                            }
                    }
                    Text("\(calendar.component(.day, from: date))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthlyGrid: some View {
        let cells = monthCells
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
            spacing: 6
        ) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                if let date {
                    completionButton(for: date) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(cellColor(for: date))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.caption2.monospacedDigit().weight(.medium))
                                    .foregroundStyle(isDone(date) ? .black : .secondary)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(isDone(date) ? 0 : 0.1))
                            }
                    }
                } else {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private var yearlyGrid: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Jan")
                Spacer()
                Text("Dec")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(
                    rows: Array(repeating: GridItem(.fixed(11), spacing: 3), count: 7),
                    spacing: 3
                ) {
                    ForEach(Array(yearCells.enumerated()), id: \.offset) { _, date in
                        if let date {
                            completionButton(for: date) {
                                RoundedRectangle(cornerRadius: 2.5)
                                    .fill(cellColor(for: date))
                                    .frame(width: 11, height: 11)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 2.5)
                                            .stroke(Color.white.opacity(isDone(date) ? 0 : 0.1))
                                    }
                            }
                        } else {
                            Color.clear.frame(width: 11, height: 11)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var monthCells: [Date?] {
        guard let first = days.first else { return [] }
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + days.map(Optional.some)
    }

    private var yearCells: [Date?] {
        guard let first = days.first else { return [] }
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + days.map(Optional.some)
    }

    private func isDone(_ date: Date) -> Bool {
        habit.completedDays.contains(TimePolicy.dayKey(date))
    }

    private func isFuture(_ date: Date) -> Bool {
        calendar.startOfDay(for: date) > calendar.startOfDay(for: .now)
    }

    private func cellColor(for date: Date) -> Color {
        if isDone(date) { return .white }
        return Color.white.opacity(isFuture(date) ? 0.025 : 0.055)
    }

    private func completionButton<Content: View>(
        for date: Date,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button { onToggle(date) } label: { content() }
            .buttonStyle(.plain)
            .disabled(isFuture(date))
            .accessibilityLabel(
                date.formatted(date: .complete, time: .omitted)
                    + (isDone(date) ? ", completed" : ", not completed")
            )
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
                if existing {
                    Button("Delete habit and history", role: .destructive) {
                        confirmingDelete = true
                    }
                }
            }
            .navigationTitle(existing ? "Edit habit" : "New habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        habit.name = habit.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if model.editLife({ state in
                            if let index = state.habits.firstIndex(where: { $0.id == habit.id }) {
                                state.habits[index].name = habit.name
                            } else {
                                state.habits.append(habit)
                            }
                        }) { dismiss() }
                    }
                    .disabled(habit.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog(
                "Delete this habit and its history?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete habit", role: .destructive) {
                    if model.editLife({ $0.habits.removeAll { $0.id == habit.id } }) { dismiss() }
                }
            }
        }
    }
}
