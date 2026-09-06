import SwiftUI
import FamilyControls

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { HomeView() }.tabItem { Label("Home", systemImage: "house") }.tag(0)
            NavigationStack { CalendarView() }.tabItem { Label("Calendar", systemImage: "calendar") }.tag(1)
            NavigationStack { HabitsView() }.tabItem { Label("Habits", systemImage: "checkmark.circle") }.tag(2)
            NavigationStack { NotesView() }.tabItem { Label("Notes", systemImage: "note.text") }.tag(3)
        }
        .onOpenURL { url in if url.scheme == "lockin" { tab = 0 } }
        .alert("LockIn", isPresented: Binding(get: { model.lastError != nil }, set: { if !$0 { model.lastError = nil } })) {
            Button("OK") { model.lastError = nil }
        } message: { Text(model.lastError ?? "") }
    }
}

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingAppPicker = false
    @State private var showingUnlock = false
    @State private var draftSelection = FamilyActivitySelection()
    @State private var confirmingSelection = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Label("LOCKED BY DEFAULT", systemImage: "lock.fill").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(statusTitle).font(.largeTitle.bold())
                    Text("Keep distractions closed. Take temporary access when you need it.").foregroundStyle(.secondary)
                    if !model.storageReady {
                        Button("Retry shared storage") { model.refreshFromSharedStore() }
                    } else if !model.authorized {
                        Button("Allow Screen Time access") { Task { await model.authorize() } }.buttonStyle(.bordered)
                        Text("Blocking needs Screen Time permission.").font(.footnote).foregroundStyle(.secondary)
                    } else {
                        if let grant = model.blocking.grant {
                            Text("Temporary access ends in")
                            Text(grant.deadline.endsAt, style: .timer).font(.title.monospacedDigit())
                            Button("Lock again now") { model.lockNow() }.buttonStyle(.bordered)
                        } else if !model.blocking.selection.isEmpty {
                            Button("Temporary unlock") { showingUnlock = true }.buttonStyle(.bordered)
                        }
                        Button("Choose blocked apps") { draftSelection = model.blocking.selection; showingAppPicker = true }
                        Picker("Wait before unlock", selection: Binding(get: { model.blocking.waitSeconds }, set: model.setWait)) {
                            ForEach(TimePolicy.waitDurations, id: \.self) { Text("\($0) seconds").tag($0) }
                        }.pickerStyle(.menu)
                    }
                }.card()
                VStack(alignment: .leading, spacing: 16) {
                    YearProgressView()
                    CalendarMonthView(compact: true)
                }.card()
                HStack(spacing: 16) {
                    NavigationLink { HabitsView() } label: { Label("Habits", systemImage: "checkmark.circle").frame(maxWidth: .infinity) }
                    NavigationLink { NotesView() } label: { Label("Notes", systemImage: "note.text").frame(maxWidth: .infinity) }
                }.buttonStyle(.bordered)
            }.padding()
        }
        .background(Color.black)
        .navigationTitle("LockIn")
        .familyActivityPicker(isPresented: $showingAppPicker, selection: $draftSelection)
        .onChange(of: showingAppPicker) { _, showing in if !showing { confirmingSelection = true } }
        .confirmationDialog("Apply this blocked selection?", isPresented: $confirmingSelection, titleVisibility: .visible) {
            Button("Apply selection") { model.updateSelection(draftSelection) }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Selected items stay blocked all day. Removing items makes them available. Any temporary access will end.") }
        .sheet(isPresented: $showingUnlock) { UnlockView().environmentObject(model) }
    }

    private var statusTitle: String {
        if !model.storageReady { return "Storage unavailable" }
        if !model.authorized { return "Set up protection" }
        if model.blocking.selection.isEmpty { return "Choose your distractions" }
        return model.blocking.grant == nil ? "Distractions locked" : "Temporary access"
    }
}

struct YearProgressView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let year = Calendar.current.component(.year, from: context.date)
            let progress = TimePolicy.yearProgress(at: context.date)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(String(year)) → \(String(year + 1))").font(.headline)
                    Spacer()
                    Text(progress, format: .percent.precision(.fractionLength(0))).monospacedDigit().foregroundStyle(.secondary)
                }
                ProgressView(value: progress).tint(.white)
                    .accessibilityLabel("Year progress")
            }
        }
    }
}

extension View {
    func card() -> some View { padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color(white: 0.09), in: RoundedRectangle(cornerRadius: 20)) }
}
