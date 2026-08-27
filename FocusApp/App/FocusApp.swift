import SwiftUI

@main
struct FocusApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(.indigo)
                .task { await model.authorize() }
        }
    }
}
