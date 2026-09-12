import SwiftUI

private enum TimerSection: String, CaseIterable, Identifiable {
    case countdown = "Countdown"
    case stopwatch = "Stopwatch"
    case alarm = "Alarm"
    var id: String { rawValue }
}

private enum FullscreenClock: String, Identifiable {
    case countdown, stopwatch
    var id: String { rawValue }
}

struct TimerView: View {
    @EnvironmentObject private var timekeeper: TimekeeperController
    @State private var section: TimerSection = .countdown
    @State private var editingAlarm: Alarm?
    @State private var fullscreenClock: FullscreenClock?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Picker("Timer mode", selection: $section) {
                    ForEach(TimerSection.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch section {
                case .countdown:
                    CountdownPanel { fullscreenClock = .countdown }
                case .stopwatch:
                    StopwatchPanel { fullscreenClock = .stopwatch }
                case .alarm:
                    AlarmsPanel(editingAlarm: $editingAlarm)
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("Timer")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editingAlarm = Alarm.newOneTimeAlarm() } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add alarm")
            }
        }
        .sheet(item: $editingAlarm) {
            AlarmEditor(alarm: $0).environmentObject(timekeeper)
        }
        .fullScreenCover(item: $fullscreenClock) { clock in
            FullscreenTimerView(clock: clock)
                .environmentObject(timekeeper)
        }
        .alert("Notifications unavailable", isPresented: Binding(
            get: { timekeeper.notificationError != nil },
            set: { if !$0 { timekeeper.notificationError = nil } }
        )) {
            Button("OK") { timekeeper.notificationError = nil }
        } message: {
            Text(timekeeper.notificationError ?? "")
        }
    }
}

private struct CountdownPanel: View {
    @EnvironmentObject private var timekeeper: TimekeeperController
    @State private var hours = 0
    @State private var minutes = 5
    @State private var seconds = 0
    let enterFullscreen: () -> Void

    private let presets = [60, 300, 600, 900, 1500, 1800]
    private var countdown: CountdownState { timekeeper.state.countdown }
    private var remaining: Int { timekeeper.countdownRemaining }
    private var isPaused: Bool {
        !countdown.isRunning && remaining > 0 && remaining < countdown.durationSeconds
    }
    private var pickerDuration: Int { hours * 3600 + minutes * 60 + seconds }

    var body: some View {
        VStack(spacing: 22) {
            Text(TimeFormat.clock(remaining, includeHours: countdown.durationSeconds >= 3600))
                .font(.system(size: 58, weight: .light, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            if !countdown.isRunning && !isPaused {
                timePicker
                presetButtons
            }

            HStack(spacing: 12) {
                if countdown.isRunning {
                    controlButton("Pause", icon: "pause.fill") { timekeeper.pauseCountdown() }
                } else if isPaused {
                    controlButton("Resume", icon: "play.fill") { timekeeper.resumeCountdown() }
                    controlButton("Reset", icon: "arrow.counterclockwise") { timekeeper.resetCountdown() }
                } else {
                    controlButton("Start", icon: "play.fill") {
                        timekeeper.startCountdown(seconds: pickerDuration)
                    }
                    .disabled(pickerDuration == 0)
                }
            }

            if countdown.isRunning || isPaused {
                Button(action: enterFullscreen) {
                    Label("Fullscreen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.bordered)
            }
        }
        .card()
        .onAppear { setPicker(to: countdown.durationSeconds) }
        .onChange(of: countdown.durationSeconds) { _, value in setPicker(to: value) }
    }

    private var timePicker: some View {
        HStack(spacing: 0) {
            wheel("Hours", selection: $hours, values: Array(0...23))
            wheel("Minutes", selection: $minutes, values: Array(0...59))
            wheel("Seconds", selection: $seconds, values: Array(0...59))
        }
        .frame(height: 150)
        .clipped()
    }

    private var presetButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { preset in
                    Button(TimePolicy.durationLabel(preset)) { setPicker(to: preset) }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private func wheel(_ title: String, selection: Binding<Int>, values: [Int]) -> some View {
        VStack(spacing: 0) {
            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .pickerStyle(.wheel)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func setPicker(to duration: Int) {
        let safe = min(86_399, max(0, duration))
        hours = safe / 3600
        minutes = (safe % 3600) / 60
        seconds = safe % 60
    }

    private func controlButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).frame(maxWidth: .infinity) }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
    }
}

private struct StopwatchPanel: View {
    @EnvironmentObject private var timekeeper: TimekeeperController
    let enterFullscreen: () -> Void

    var body: some View {
        VStack(spacing: 26) {
            Text(TimeFormat.stopwatch(timekeeper.stopwatchElapsed))
                .font(.system(size: 54, weight: .light, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                if timekeeper.state.stopwatch.isRunning {
                    controlButton("Pause", icon: "pause.fill") { timekeeper.pauseStopwatch() }
                } else {
                    controlButton(
                        timekeeper.stopwatchElapsed > 0 ? "Resume" : "Start",
                        icon: "play.fill"
                    ) { timekeeper.startStopwatch() }
                }
                Button("Reset") { timekeeper.resetStopwatch() }
                    .buttonStyle(.bordered)
                    .disabled(timekeeper.stopwatchElapsed == 0)
            }

            if timekeeper.state.stopwatch.isRunning || timekeeper.stopwatchElapsed > 0 {
                Button(action: enterFullscreen) {
                    Label("Fullscreen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.bordered)
            }
        }
        .card()
    }

    private func controlButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).frame(maxWidth: .infinity) }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
    }
}

private struct AlarmsPanel: View {
    @EnvironmentObject private var timekeeper: TimekeeperController
    @Binding var editingAlarm: Alarm?

    var body: some View {
        VStack(spacing: 12) {
            if timekeeper.state.alarms.isEmpty {
                ContentUnavailableView(
                    "No alarms",
                    systemImage: "alarm",
                    description: Text("Tap + to create an alarm.")
                )
                .frame(maxWidth: .infinity, minHeight: 260)
                .card()
            } else {
                ForEach(timekeeper.state.alarms) { alarm in
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(alarm.timeLabel)
                                .font(.title2.monospacedDigit().weight(.semibold))
                            Text(alarm.scheduleLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("Enabled", isOn: Binding(
                            get: { alarm.enabled },
                            set: { timekeeper.setAlarmEnabled(alarm.id, enabled: $0) }
                        ))
                        .labelsHidden()
                        Button { editingAlarm = alarm } label: { Image(systemName: "pencil") }
                            .accessibilityLabel("Edit alarm")
                        Button(role: .destructive) { timekeeper.deleteAlarm(alarm.id) } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("Delete alarm")
                    }
                    .card()
                }
            }
        }
    }
}

private struct AlarmEditor: View {
    @EnvironmentObject private var timekeeper: TimekeeperController
    @Environment(\.dismiss) private var dismiss
    @State private var alarm: Alarm
    @State private var repeats: Bool
    @State private var date: Date
    @State private var repeatWeekdays: Set<Int>

    private let calendar = Calendar.current
    private var existing: Bool { timekeeper.state.alarms.contains { $0.id == alarm.id } }

    init(alarm: Alarm) {
        _alarm = State(initialValue: alarm)
        _repeats = State(initialValue: alarm.isRepeating)
        _date = State(initialValue: alarm.editorDate)
        _repeatWeekdays = State(initialValue: alarm.repeatWeekdays)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if repeats {
                        DatePicker(
                            "Time",
                            selection: $date,
                            displayedComponents: [.hourAndMinute]
                        )
                        .datePickerStyle(.wheel)
                    } else {
                        DatePicker(
                            "Date and time",
                            selection: $date,
                            in: Date()...Date.distantFuture,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                    }
                    Toggle("Repeat", isOn: $repeats)
                }

                if repeats {
                    Section("Repeat on") {
                        HStack(spacing: 6) {
                            ForEach(weekdayOrder, id: \.self) { weekday in
                                Button {
                                    if repeatWeekdays.contains(weekday) { repeatWeekdays.remove(weekday) }
                                    else { repeatWeekdays.insert(weekday) }
                                } label: {
                                    Text(calendar.veryShortWeekdaySymbols[weekday - 1])
                                        .font(.caption.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 34)
                                        .foregroundStyle(repeatWeekdays.contains(weekday) ? .black : .white)
                                        .background(
                                            repeatWeekdays.contains(weekday) ? Color.white : Color.white.opacity(0.08),
                                            in: Circle()
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(calendar.weekdaySymbols[weekday - 1])
                                .accessibilityAddTraits(repeatWeekdays.contains(weekday) ? .isSelected : [])
                            }
                        }
                    }
                }

                Section {
                    Toggle("Enabled", isOn: $alarm.enabled)
                }

                if existing {
                    Section {
                        Button("Delete alarm", role: .destructive) {
                            timekeeper.deleteAlarm(alarm.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(existing ? "Edit alarm" : "New alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(repeats && repeatWeekdays.isEmpty)
                }
            }
            .onChange(of: repeats) { _, isRepeating in
                if !isRepeating, date <= Date() {
                    date = Date().addingTimeInterval(300)
                }
            }
        }
    }

    private var weekdayOrder: [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    private func save() {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        alarm.timeMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        alarm.repeatWeekdays = repeats ? repeatWeekdays : []
        alarm.oneTimeDate = repeats ? nil : calendar.date(bySetting: .second, value: 0, of: date)
        if timekeeper.saveAlarm(alarm) { dismiss() }
    }
}

private struct FullscreenTimerView: View {
    @EnvironmentObject private var timekeeper: TimekeeperController
    @Environment(\.dismiss) private var dismiss
    @State private var controlsVisible = false
    @State private var hideTask: Task<Void, Never>?
    let clock: FullscreenClock

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text(displayText)
                .font(.system(size: 84, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .padding(.horizontal, 24)

            if controlsVisible {
                VStack {
                    Spacer()
                    HStack(spacing: 14) {
                        Button(action: toggleRunning) {
                            Label(controlTitle, systemImage: isRunning ? "pause.fill" : "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .foregroundStyle(.black)

                        Button { dismiss() } label: {
                            Label("Exit Fullscreen", systemImage: "xmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(24)
                }
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { revealControls() }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onDisappear { hideTask?.cancel() }
    }

    private var displayText: String {
        switch clock {
        case .countdown:
            return TimeFormat.clock(
                timekeeper.countdownRemaining,
                includeHours: timekeeper.state.countdown.durationSeconds >= 3600
            )
        case .stopwatch:
            return TimeFormat.stopwatch(timekeeper.stopwatchElapsed)
        }
    }

    private var isRunning: Bool {
        switch clock {
        case .countdown: timekeeper.state.countdown.isRunning
        case .stopwatch: timekeeper.state.stopwatch.isRunning
        }
    }

    private var controlTitle: String { isRunning ? "Pause" : "Resume" }

    private func toggleRunning() {
        switch clock {
        case .countdown:
            isRunning ? timekeeper.pauseCountdown() : timekeeper.resumeCountdown()
        case .stopwatch:
            isRunning ? timekeeper.pauseStopwatch() : timekeeper.startStopwatch()
        }
        revealControls()
    }

    private func revealControls() {
        hideTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) { controlsVisible = true }
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.2)) { controlsVisible = false }
            }
        }
    }
}

private extension Alarm {
    static func newOneTimeAlarm(calendar: Calendar = .current) -> Alarm {
        let now = Date().addingTimeInterval(300)
        let rounded = calendar.date(bySetting: .second, value: 0, of: now) ?? now
        let components = calendar.dateComponents([.hour, .minute], from: rounded)
        return Alarm(
            timeMinutes: (components.hour ?? 0) * 60 + (components.minute ?? 0),
            oneTimeDate: rounded
        )
    }

    var editorDate: Date {
        if let oneTimeDate { return oneTimeDate }
        return Calendar.current.date(
            bySettingHour: timeMinutes / 60,
            minute: timeMinutes % 60,
            second: 0,
            of: .now
        ) ?? .now
    }

    var timeLabel: String {
        editorDate.formatted(.dateTime.hour().minute())
    }

    var scheduleLabel: String {
        if isRepeating {
            if repeatWeekdays.count == 7 { return "Every day" }
            return repeatWeekdays.sorted().map {
                Calendar.current.shortWeekdaySymbols[$0 - 1]
            }.joined(separator: " · ")
        }
        guard let oneTimeDate else { return "One time" }
        return "One time · " + oneTimeDate.formatted(.dateTime.month(.abbreviated).day())
    }
}
