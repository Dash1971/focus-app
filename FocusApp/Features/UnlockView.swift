import SwiftUI
import FamilyControls

struct UnlockView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var chosen = FamilyActivitySelection()
    @State private var seconds = 300
    @State private var customMinutes = 45

    private var duration: Int { seconds == -1 ? customMinutes * 60 : seconds }
    private var waiting: Bool { model.waitRemaining != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Choose what you need. Everything else stays locked.").foregroundStyle(.secondary)
                    ForEach(Array(model.blocking.selection.applicationTokens), id: \.self) { token in
                        Button { model.cancelWait(); chosen = .init(); chosen.applicationTokens = [token] } label: {
                            HStack { Label(token); Spacer(); if chosen.applicationTokens.contains(token) { Image(systemName: "checkmark") } }
                        }
                    }
                    ForEach(Array(model.blocking.selection.categoryTokens), id: \.self) { token in
                        Button { model.cancelWait(); chosen = .init(); chosen.categoryTokens = [token] } label: {
                            HStack { Label(token); Spacer(); if chosen.categoryTokens.contains(token) { Image(systemName: "checkmark") } }
                        }
                    }
                    ForEach(Array(model.blocking.selection.webDomainTokens), id: \.self) { token in
                        Button { model.cancelWait(); chosen = .init(); chosen.webDomainTokens = [token] } label: {
                            HStack { Label(token); Spacer(); if chosen.webDomainTokens.contains(token) { Image(systemName: "checkmark") } }
                        }
                    }
                } header: { Text("Blocked items") } footer: {
                    Text("A category unlock applies to that entire category. Apps or websites also selected individually remain blocked; unlock those individually.")
                }
                Section("Access duration") {
                    Picker("Access duration", selection: $seconds) {
                        ForEach(TimePolicy.unlockDurations, id: \.self) { Text(TimePolicy.durationLabel($0)).tag($0) }
                        Text("Custom").tag(-1)
                    }.pickerStyle(.wheel).frame(height: 150)
                    if seconds == -1 {
                        Picker("Custom duration", selection: $customMinutes) {
                            ForEach(1...1440, id: \.self) { Text("\($0) minutes").tag($0) }
                        }.pickerStyle(.wheel).frame(height: 130)
                    }
                }.disabled(waiting)
                Section {
                    if let remaining = model.waitRemaining {
                        if remaining > 0 {
                            Text("Take a breath. \(remaining)s remaining.").font(.headline).monospacedDigit()
                            Text("Stay in LockIn while you wait.").foregroundStyle(.secondary)
                        } else {
                            Button("Unlock for \(TimePolicy.durationLabel(duration))") {
                                if model.unlock(chosen, seconds: duration) { dismiss() }
                            }
                        }
                        Button("Cancel wait", role: .cancel) { model.cancelWait() }
                    } else {
                        Button("Wait \(model.blocking.waitSeconds) seconds to unlock") { model.startWait() }
                            .disabled(chosen.isEmpty || !model.authorized || !model.storageReady)
                    }
                } footer: {
                    Text("Access relocks automatically. iOS controls background callback timing, so relocking may be delayed.")
                }
            }
            .navigationTitle("Temporary unlock")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onDisappear { model.cancelWait() }
        }
    }
}
