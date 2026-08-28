import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }
            NavigationStack { SchedulesView() }
                .tabItem { Label("Schedules", systemImage: "calendar") }
            NavigationStack { ProgressViewScreen() }
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
        }
        .alert("LockIn", isPresented: Binding(
            get: { model.lastError != nil },
            set: { if !$0 { model.lastError = nil } }
        )) {
            Button("OK") { model.lastError = nil }
        } message: {
            Text(model.lastError ?? "")
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingAppPicker = false
    @State private var openingFocus = false
    @State private var openingTimer = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let session = model.activeSession {
                    ActiveSessionCard(session: session)
                } else if let schedule = model.activeScheduleNow {
                    ActiveScheduleCard(schedule: schedule)
                } else {
                    NavigationLink { StartFocusView() } label: {
                        Label("START FOCUS", systemImage: "scope")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack(spacing: 12) {
                    NavigationLink { CountdownTimerView() } label: { ActionTile(title: "TIMER", icon: "timer") }
                    NavigationLink { IntervalTimerView() } label: { ActionTile(title: "INTERVAL", icon: "repeat") }
                }

                Button { showingAppPicker = true } label: {
                    Label("BLOCK APPS", systemImage: "hand.raised.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                }

                HStack {
                    StatTile(value: "\(model.focusMinutesToday)m", label: "Focus today")
                    StatTile(value: "\(model.sessionsToday)", label: "Sessions")
                    StatTile(value: "\(model.challengesCompleted)", label: "Challenges")
                }
            }
            .padding()
        }
        .navigationTitle("LockIn")
        .familyActivityPicker(isPresented: $showingAppPicker, selection: Binding(
            get: { model.selection },
            set: { model.updateSelection($0) }
        ))
        .navigationDestination(isPresented: $openingFocus) { StartFocusView() }
        .navigationDestination(isPresented: $openingTimer) { CountdownTimerView() }
        .onOpenURL { url in
            guard url.scheme == "lockin" else { return }
            if url.host == "focus" { openingFocus = true }
            if url.host == "timer" { openingTimer = true }
        }
    }
}

private struct ActionTile: View {
    let title: String
    let icon: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.title)
            Text(title).font(.headline)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}
