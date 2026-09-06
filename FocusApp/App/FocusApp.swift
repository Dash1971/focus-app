import SwiftUI

@main
struct LockInApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .tint(.white)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.refreshFromSharedStore() }
                    else { model.cancelWait() }
                }
        }
    }
}
