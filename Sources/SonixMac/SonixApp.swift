import SwiftUI

@main
struct SonixApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 600)
                .preferredColorScheme(.dark) // Sonix usually has a dark theme
                .onAppear {
                    appState.loadSavedSourceFolder()
                    appState.startQueueProcessor()
                }
        }
        .windowStyle(.hiddenTitleBar) // More modern look
        
        Settings {
            SettingsView()
        }
    }
}
