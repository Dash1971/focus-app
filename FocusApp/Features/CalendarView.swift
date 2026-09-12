import SwiftUI

extension EventColor {
    var tint: Color {
        switch self {
        case .gray: .gray
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .red: .red
        }
    }
}

struct CalendarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedDate = Date()
    @State private var editingEvent: CalendarEvent?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                YearProgressView(startYear: 2026)
                    .card()
                CalendarMonthView(
                    selectedDate: $selectedDate,
                    onAddEvent: { editingEvent = newEvent(on: selectedDate) },
                    onEditEvent: { editingEvent = $0 }
                )
                .card()
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("Calendar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editingEvent = newEvent(on: selectedDate) } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add event")
                .disabled(!model.lifeReady)
            }
        }
        .sheet(item: $editingEvent) {
            EventEditor(event: $0).environmentObject(model)
        }
    }

    private func newEvent(on date: Date) -> CalendarEvent {
        CalendarEvent(title: "", day: TimePolicy.dayKey(date))
    }
}

struct CalendarMonthView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var selectedDate: Date
    let onAddEvent: () -> Void
    let onEditEvent: (CalendarEvent) -> Void

    @State private var month = Date()
    private let calendar = Calendar.current
    private var days: [Date] { TimePolicy.monthDays(containing: month) }
    private var selectedEvents: [CalendarEvent] { events(on: selectedDate) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            VStack(alignment: .leading, spacing: 16) {
                monthHeader
                weekdayHeader
                monthGrid(today: timeline.date)
                selectedDayHeader
                eventList
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous month")
            Spacer()
            Text(month, format: .dateTime.month(.wide).year())
                .font(.headline)
            Spacer()
            Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Next month")
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(0..<7, id: \.self) { index in
                Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + index) % 7])
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func monthGrid(today: Date) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 6) {
            ForEach(0..<leadingSpaces, id: \.self) { _ in
                Color.clear.frame(height: 58)
            }
            ForEach(days, id: \.self) { date in
                dayCell(date, today: today)
            }
        }
    }

    private var selectedDayHeader: some View {
        HStack {
            Text(selectedDate, format: .dateTime.month(.wide).day())
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button("Today") {
                month = .now
                selectedDate = .now
            }
            Button(action: onAddEvent) { Image(systemName: "plus") }
                .accessibilityLabel("Add event on selected date")
                .disabled(!model.lifeReady)
        }
    }

    @ViewBuilder
    private var eventList: some View {
        if selectedEvents.isEmpty {
            Text("No events on this date.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            ForEach(selectedEvents) { event in
                Button { onEditEvent(event) } label: {
                    HStack {
                        Circle().fill(event.color.tint).frame(width: 8, height: 8)
                        Text(event.title)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if event.important {
                            Image(systemName: "star.fill").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var leadingSpaces: Int {
        days.first.map {
            (calendar.component(.weekday, from: $0) - calendar.firstWeekday + 7) % 7
        } ?? 0
    }

    private func events(on date: Date) -> [CalendarEvent] {
        model.life.events.filter { $0.day == TimePolicy.dayKey(date) }
    }

    private func moveMonth(_ amount: Int) {
        guard let start = calendar.dateInterval(of: .month, for: month)?.start,
              let next = calendar.date(byAdding: .month, value: amount, to: start) else { return }
        month = next
        selectedDate = next
    }

    private func dayCell(_ date: Date, today: Date) -> some View {
        let items = events(on: date)
        let selected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: today)

        return Button { selectedDate = date } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Color.black : Color.primary)
                    .frame(width: 28, height: 28)
                    .background(isToday ? Color.white : Color.clear, in: Circle())
                HStack(spacing: 2) {
                    ForEach(Array(items.prefix(3))) { event in
                        Circle().fill(event.color.tint).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Color.white.opacity(selected ? 0.07 : 0), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            date.formatted(date: .complete, time: .omitted)
                + (isToday ? ", today" : "")
                + ", \(items.count) events"
                + (items.contains(where: \.important) ? ", important date" : "")
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct EventEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var event: CalendarEvent
    @State private var date = Date()
    @State private var confirmingDelete = false
    private var existing: Bool { model.life.events.contains { $0.id == event.id } }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Event name", text: $event.title)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Picker("Color", selection: $event.color) {
                    ForEach(EventColor.allCases) { color in
                        Label(color.rawValue.capitalized, systemImage: "circle.fill")
                            .foregroundStyle(color.tint)
                            .tag(color)
                    }
                }
                Toggle("Important date", isOn: $event.important)
                if existing {
                    Button("Delete event", role: .destructive) { confirmingDelete = true }
                }
            }
            .navigationTitle(existing ? "Edit event" : "New event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.lifeReady)
                }
            }
            .onAppear {
                let parts = event.day.split(separator: "-").compactMap { Int($0) }
                if parts.count == 3 {
                    date = Calendar.current.date(from: DateComponents(
                        year: parts[0], month: parts[1], day: parts[2]
                    )) ?? .now
                }
            }
            .confirmationDialog(
                "Delete this event?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete event", role: .destructive) {
                    if model.editLife({ $0.events.removeAll { $0.id == event.id } }) { dismiss() }
                }
            }
        }
    }

    private func save() {
        event.title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.day = TimePolicy.dayKey(date)
        if model.editLife({ state in
            if let index = state.events.firstIndex(where: { $0.id == event.id }) {
                state.events[index] = event
            } else {
                state.events.append(event)
            }
        }) { dismiss() }
    }
}
