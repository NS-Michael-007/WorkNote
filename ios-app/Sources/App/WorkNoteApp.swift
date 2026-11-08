import SwiftUI

@main
struct WorkNoteApp: App {

    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(model.settings)
                .preferredColorScheme(model.settings.preferredColorScheme)
                .task { model.bootstrap() }
        }
    }
}
