import SwiftUI
import FamilyControls
import UIKit

struct UnlockView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var chosen = FamilyActivitySelection()
    @State private var seconds = 300
    @State private var granting = false
    @StateObject private var camera = NoseCameraController(mode: .facePresence)

    var body: some View {
        NavigationStack {
            Group {
                if let remaining = model.waitRemaining, remaining > 0 {
                    cameraWait(remaining: remaining)
                } else if model.waitRemaining == 0 {
                    selectionForm
                } else {
                    ProgressView("Preparing temporary access…")
                }
            }
            .navigationTitle("Temporary unlock")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .onAppear { beginWait() }
        .onDisappear { model.cancelWait(); camera.stop() }
        .onReceive(camera.$faceSample) { sample in
            guard let sample, scenePhase == .active else { return }
            model.observeWaitFace(visible: sample.visible, uptime: sample.uptime)
        }
        .onChange(of: model.waitRemaining) { _, remaining in
            if remaining == 0 { camera.stop() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                model.cancelWait()
                camera.stop()
                if phase == .background { dismiss() }
            } else { beginWait() }
        }
    }

    private func beginWait() {
        model.startWait()
        if let remaining = model.waitRemaining, remaining > 0 { camera.start() }
    }

    private func cameraWait(remaining: Int) -> some View {
        ZStack {
            NoseCameraPreview(session: camera.session)
                .ignoresSafeArea()
                .accessibilityLabel("Live front camera preview")
            Color.black.opacity(0.25).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    Text("\(remaining)")
                        .font(.system(size: 72, weight: .semibold)).monospacedDigit()
                    Text(camera.status == .tracking ? "Keep your face visible" : "Show your face to begin")
                        .font(.title2).multilineTextAlignment(.center)
                    Text("Keep your face in the front camera for the entire wait. If your face disappears, the countdown resets. Leaving this screen cancels the wait.")
                        .multilineTextAlignment(.center)
                    if [.denied, .unavailable, .failed].contains(camera.status) {
                        Text(camera.status == .denied ? "Camera access is required for this wait." : "The front camera is unavailable. Access remains locked.")
                            .font(.headline).multilineTextAlignment(.center)
                        if camera.status == .denied {
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }.buttonStyle(.borderedProminent)
                        }
                    } else if [.starting, .requestingPermission].contains(camera.status) {
                        ProgressView("Starting camera…")
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))
                .padding(24)
            }.defaultScrollAnchor(.center)
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
