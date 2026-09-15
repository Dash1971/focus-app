import SwiftUI
import FamilyControls

struct UnlockView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var chosen = FamilyActivitySelection()
    @State private var seconds = 300
    @State private var granting = false

    var body: some View {
        NavigationStack {
            Group {
                if let remaining = model.waitRemaining, remaining > 0 {
                    VStack(spacing: 18) {
                        Text("\(remaining)").font(.system(size: 72, weight: .light)).monospacedDigit()
                        Text("Take a moment").font(.title2)
                        Text("App selection opens automatically when the wait ends.")
                            .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black)
                } else if model.waitRemaining == 0 {
                    selectionForm
                } else {
                    ProgressView("Preparing temporary access…")
                }
            }
            .navigationTitle("Temporary unlock")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { model.startWait() }
            .onDisappear { model.cancelWait() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { model.cancelWait(); dismiss() }
            }
        }
    }

    private var selectionForm: some View {
        Form {
            Section {
                Text("Choose what you need. Everything else stays locked.").foregroundStyle(.secondary)
                ForEach(Array(model.blocking.selection.applicationTokens), id: \.self) { token in
                    Button {
                        if chosen.applicationTokens.contains(token) { chosen.applicationTokens.remove(token) }
                        else { chosen.applicationTokens.insert(token) }
                    } label: {
                        HStack { Label(token); Spacer(); if chosen.applicationTokens.contains(token) { Image(systemName: "checkmark") } }
                    }
                }
                ForEach(Array(model.blocking.selection.categoryTokens), id: \.self) { token in
                    Button {
                        if chosen.categoryTokens.contains(token) { chosen.categoryTokens.remove(token) }
                        else { chosen.categoryTokens.insert(token) }
                    } label: {
                        HStack { Label(token); Spacer(); if chosen.categoryTokens.contains(token) { Image(systemName: "checkmark") } }
                    }
                }
                ForEach(Array(model.blocking.selection.webDomainTokens), id: \.self) { token in
                    Button {
                        if chosen.webDomainTokens.contains(token) { chosen.webDomainTokens.remove(token) }
                        else { chosen.webDomainTokens.insert(token) }
                    } label: {
                        HStack { Label(token); Spacer(); if chosen.webDomainTokens.contains(token) { Image(systemName: "checkmark") } }
                    }
                }
            } header: { Text("Blocked items") } footer: {
                Text("A category unlock covers that category. If an app or website is also blocked individually, select it as well.")
            }
            Section("Access duration") {
                Picker("Access duration", selection: $seconds) {
                    ForEach(TimePolicy.unlockDurations, id: \.self) { Text(TimePolicy.durationLabel($0)).tag($0) }
                }.pickerStyle(.wheel).frame(height: 180)
            }
            Section {
                Button("Unlock selected apps") {
                    granting = true
                    if model.unlock(chosen, seconds: seconds) { dismiss() }
                    else { granting = false; dismiss() }
                }.disabled(chosen.isEmpty || !model.authorized || !model.storageReady || granting)
            } footer: { Text("Temporary access ends automatically. Maximum duration: 2 hours.") }
        }
    }
}
