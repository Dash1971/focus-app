import SwiftUI
import FamilyControls

struct UnlockView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var chosen = FamilyActivitySelection()
    @State private var seconds = 300
    @State private var requestSubmitted = false
    @State private var granting = false

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
                .disabled(waiting)
                Section("Access duration") {
                    Picker("Access duration", selection: $seconds) {
                        ForEach(TimePolicy.unlockDurations, id: \.self) { Text(TimePolicy.durationLabel($0)).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 180)
                }.disabled(waiting)
                Section {
                    if let remaining = model.waitRemaining {
                        if remaining > 0 {
                            VStack(spacing: 10) {
                                Text("\(remaining)")
                                    .font(.system(size: 52, weight: .light, design: .rounded))
                                    .monospacedDigit()
                                Text("Waiting")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ProgressView("Granting temporary access…")
                                .frame(maxWidth: .infinity)
                        }
                        Button("Cancel wait", role: .cancel) { model.cancelWait() }
                    } else {
                        Button("Request access") {
                            requestSubmitted = true
                            model.startWait()
                        }
                            .disabled(chosen.isEmpty || !model.authorized || !model.storageReady)
                    }
                } footer: {
                    Text("Access relocks automatically. iOS controls background callback timing, so relocking may be delayed.")
                }
            }
            .navigationTitle("Temporary unlock")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onChange(of: model.waitRemaining) { _, remaining in
                guard requestSubmitted, remaining == 0, !granting else { return }
                granting = true
                if model.unlock(chosen, seconds: seconds) {
                    dismiss()
                } else {
                    requestSubmitted = false
                    granting = false
                }
            }
            .onDisappear { model.cancelWait() }
        }
    }
}
