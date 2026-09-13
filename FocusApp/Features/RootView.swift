import SwiftUI
import FamilyControls

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

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: statusIcon)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.secondary)
            Text(statusTitle)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            if !model.storageReady {
                Button("Retry") { model.refreshFromSharedStore() }
                    .buttonStyle(.bordered)
            } else if !model.authorized {
                Button("Allow Screen Time access") {
                    Task { await model.authorize() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
            } else if let grant = model.blocking.grant {
                Text(grant.deadline.endsAt, style: .timer)
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Button("Lock now") { model.lockNow() }
                    .buttonStyle(.bordered)
            } else if !model.blocking.selection.isEmpty {
                Button("Temporary unlock") { showingUnlock = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.black)
        .navigationTitle("Restrictions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    RestrictionsSettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Restriction settings")
            }
        }
        .sheet(isPresented: $showingUnlock) {
            UnlockView().environmentObject(model)
        }
    }

    private var statusTitle: String {
        if !model.storageReady { return "Storage unavailable" }
        if !model.authorized { return "Set up restrictions" }
        if model.blocking.selection.isEmpty { return "No apps selected" }
        return model.blocking.grant == nil ? "Restrictions active" : "Temporary access"
    }

    private var statusIcon: String {
        model.blocking.grant == nil ? "lock.fill" : "lock.open.fill"
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
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("\(String(startYear)) → \(String(startYear + 1))")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress)
                    .tint(.white)
                    .accessibilityLabel("\(String(startYear)) to \(String(startYear + 1)) progress")
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
