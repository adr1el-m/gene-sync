import SwiftUI

@main
struct GeneSyncApp: App {
    @StateObject private var session = GeneSyncSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(GeneSyncTheme.primary)
                .statusBar(hidden: true)
        }
    }
}
