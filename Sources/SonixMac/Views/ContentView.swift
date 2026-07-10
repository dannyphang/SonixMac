import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var backend = BackendManager.shared
    @AppStorage("backendFolderPath") var backendFolderPath: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                SidebarView()
            } detail: {
                MainAppView()
            }
            
            Divider()
            
            HStack(spacing: 12) {
                // Backend Status - clickable to toggle
                Button(action: {
                    if backend.isRunning {
                        backend.stopBackend()
                    } else {
                        backend.startBackend(at: backendFolderPath)
                    }
                }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(backend.isRunning ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(backend.isRunning ? "Backend: Running" : "Backend: Stopped")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.plain)
                .help(backend.isRunning ? "Click to stop backend" : "Click to start backend")
                
                Divider().frame(height: 12)
                
                // Current Song Playing
                HStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .font(.system(size: 11))
                    Text(appState.currentTrack != nil ? "Playing: \(appState.currentTrack!.name)" : "Not Playing")
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 250, alignment: .leading)
                }
                
                Divider().frame(height: 12)
                
                // Notifications
                HStack(spacing: 4) {
                    Image(systemName: appState.statusBarIcon)
                        .font(.system(size: 11))
                    Text(appState.statusBarMessage)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
            .foregroundColor(.secondary)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}
