import SwiftUI

@main
struct LockInApp: App {
    @UIApplicationDelegateAdaptor(NotificationBridge.self) private var notificationBridge
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = AppModel()
    @StateObject private var timekeeper = TimekeeperController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(timekeeper)
                .preferredColorScheme(.dark)
                .tint(.white)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        model.refreshFromSharedStore()
                        timekeeper.refresh()
                    }
                    else { model.cancelWait() }
                }
        }
    }
}
