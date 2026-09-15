import SwiftUI
import FamilyControls
import DeviceActivity

private enum MainSection: String, CaseIterable, Identifiable {
    case restrictions = "Restrictions"
    case calendar = "Calendar"
    case habits = "Habits"
    case notes = "Notes"
    case timer = "Timer"
    case miniGames = "Mini Games"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .restrictions: "lock.fill"
        case .calendar: "calendar"
        case .habits: "checkmark.circle"
        case .notes: "note.text"
        case .timer: "clock"
        case .miniGames: "gamecontroller"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var timekeeper: TimekeeperController
    @State private var section: MainSection = .restrictions

    var body: some View {
        currentSection
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MainNavigationBar(selection: $section)
            }
            .onOpenURL { url in
                if url.scheme == "lockin" { section = .restrictions }
            }
            .alert("LockIn", isPresented: Binding(
                get: { model.lastError != nil },
                set: { if !$0 { model.lastError = nil } }
            )) {
                Button("OK") { model.lastError = nil }
            } message: {
                Text(model.lastError ?? "")
            }
            .alert(item: $timekeeper.activeSignal) { signal in
                Alert(
                    title: Text(signal.title),
                    message: Text(signal.message),
                    dismissButton: .default(Text("Stop")) { timekeeper.dismissSignal() }
                )
            }
    }

    @ViewBuilder
    private var currentSection: some View {
        switch section {
        case .restrictions: NavigationStack { RestrictionsView() }
        case .calendar: NavigationStack { CalendarView() }
        case .habits: NavigationStack { HabitsView() }
        case .notes: NavigationStack { NotesView() }
        case .timer: NavigationStack { TimerView() }
        case .miniGames: NavigationStack { MiniGamesView() }
        }
    }
}

private struct MainNavigationBar: View {
    @Binding var selection: MainSection

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: section.icon)
                            .font(.system(size: 16, weight: .medium))
                        Text(section.rawValue)
                            .font(.system(size: 8, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == section ? Color.white : Color.gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == section ? .isSelected : [])
            }
        }
        .padding(.horizontal, 4)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().opacity(0.35) }
    }
}

struct RestrictionsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingUnlock = false
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Today's Activity")
                .font(.title3.weight(.semibold))
                .padding(.top, 18)

            if model.authorized {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    DeviceActivityReport(
                        .init(AppConstants.dailyActivityReport),
                        filter: dailyActivityFilter(at: context.date)
                    )
                    .frame(height: 148)
                }
                .padding(.top, 14)
            } else {
                ActivityStatsPlaceholder(state: model.blocking)
                    .padding(.top, 14)
            }

            Spacer(minLength: 28)

            if !model.storageReady {
                Button("Retry") { model.refreshFromSharedStore() }
                    .buttonStyle(LockInPrimaryButtonStyle())
            } else if !model.authorized {
                Button("Allow Screen Time access") {
                    Task { await model.authorize() }
                }
                .buttonStyle(LockInPrimaryButtonStyle())
            } else if let grant = model.blocking.grant {
                HStack {
                    Text("Temporary access")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(grant.deadline.endsAt, style: .timer)
                        .font(.headline.monospacedDigit())
                }
                .padding(.bottom, 12)
                Button("Lock now") { model.lockNow() }
                    .buttonStyle(LockInPrimaryButtonStyle())
            } else if !model.blocking.selection.isEmpty {
                Button("Temporary unlock") { showingUnlock = true }
                    .buttonStyle(LockInPrimaryButtonStyle())
            } else {
                Button("Choose blocked apps") { showingSettings = true }
                    .buttonStyle(LockInPrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
        .background(Color.black)
        .navigationTitle("Restrictions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Restriction settings")
            }
        }
        .sheet(isPresented: $showingUnlock) {
            UnlockView().environmentObject(model)
        }
        .sheet(isPresented: $showingSettings) {
            RestrictionsSettingsFlow(
                requiresWait: model.authorized && !model.blocking.selection.isEmpty,
                waitSeconds: model.blocking.waitSeconds
            )
            .environmentObject(model)
        }
        .onAppear { model.refreshFromSharedStore() }
    }

    private func dailyActivityFilter(at date: Date) -> DeviceActivityFilter {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = max(date, start.addingTimeInterval(1))
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: end)),
            devices: .init([.iPhone])
        )
    }
}

private struct ActivityStatsPlaceholder: View {
    let state: BlockingState

    var body: some View {
        let activity = state.unlockActivity()
        HStack(spacing: 0) {
            stat("UNLOCKS", "\(activity.count)")
            stat("UNLOCK TIME", Self.duration(activity.duration))
            stat("SCREEN TIME", "—")
        }
        .padding(.horizontal, 20)
        .frame(height: 148)
        .background(Color(white: 0.055), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.14)))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 { return remainder > 0 ? "\(hours)h \(remainder)m" : "\(hours)h" }
        return "\(minutes)m"
    }
}

private struct LockInPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(configuration.isPressed ? Color.white.opacity(0.82) : .white, in: RoundedRectangle(cornerRadius: 17))
    }
}

private struct RestrictionsSettingsFlow: View {
    @Environment(\.dismiss) private var dismiss
    @State private var accessGranted: Bool
    let requiresWait: Bool
    let waitSeconds: Int

    init(requiresWait: Bool, waitSeconds: Int) {
        self.requiresWait = requiresWait
        self.waitSeconds = waitSeconds
        _accessGranted = State(initialValue: !requiresWait)
    }

    var body: some View {
        NavigationStack {
            if accessGranted {
                RestrictionsSettingsView()
            } else {
                SettingsWaitView(seconds: waitSeconds) { accessGranted = true }
                    .navigationTitle("Settings locked")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private struct SettingsWaitView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var startedUptime: TimeInterval?
    @State private var remaining: Int
    let seconds: Int
    let completed: () -> Void
    private let ticks = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    init(seconds: Int, completed: @escaping () -> Void) {
        self.seconds = seconds
        self.completed = completed
        _remaining = State(initialValue: seconds)
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("\(remaining)")
                .font(.system(size: 84, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
            Text("Changing restrictions will be available when the wait ends.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(.bordered)
        }
        .padding(24)
        .background(Color.black)
        .onAppear {
            startedUptime = ProcessInfo.processInfo.systemUptime
            remaining = seconds
        }
        .onReceive(ticks) { _ in
            guard let startedUptime else { return }
            let value = max(0, Int(ceil(Double(seconds) - (ProcessInfo.processInfo.systemUptime - startedUptime))))
            remaining = value
            if value == 0 { completed() }
        }
    }
}

private struct RestrictionsSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingAppPicker = false
    @State private var draftSelection = FamilyActivitySelection()
    @State private var confirmingSelection = false

    var body: some View {
        Form {
            Section("Blocked apps") {
                Button("Choose apps, categories and websites") {
                    draftSelection = model.blocking.selection
                    showingAppPicker = true
                }
                if model.blocking.selection.isEmpty {
                    Text("Nothing selected")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Unlock waiting time") {
                Picker("Wait before unlock", selection: Binding(
                    get: { model.blocking.waitSeconds },
                    set: model.setWait
                )) {
                    ForEach(TimePolicy.waitDurations, id: \.self) { seconds in
                        Text("\(seconds) seconds").tag(seconds)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(isPresented: $showingAppPicker, selection: $draftSelection)
        .onChange(of: showingAppPicker) { _, showing in
            if !showing { confirmingSelection = true }
        }
        .confirmationDialog(
            "Apply this blocked selection?",
            isPresented: $confirmingSelection,
            titleVisibility: .visible
        ) {
            Button("Apply selection") { model.updateSelection(draftSelection) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removing selected items makes them available and ends any temporary access.")
        }
    }
}

struct YearProgressView: View {
    let startYear: Int

    init(startYear: Int = 2026) {
        self.startYear = startYear
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let progress = TimePolicy.yearProgress(from: startYear, at: context.date)
            VStack(spacing: 9) {
                HStack {
                    Text(String(startYear))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(String(startYear + 1))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.subheadline.weight(.semibold))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(String(startYear)) to \(String(startYear + 1)) progress")
                .accessibilityValue(progress.formatted(.percent.precision(.fractionLength(0))))
                ProgressView(value: progress)
                    .tint(.white)
                    .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    func card() -> some View {
        padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: 0.09), in: RoundedRectangle(cornerRadius: 20))
    }
}
