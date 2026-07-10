import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        if let currentTrack = appState.currentTrack {
            if currentTrack.isSeparated {
                PlayerView()
            } else if currentTrack.isProcessing {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Separating \(currentTrack.name)...")
                        .font(.headline)
                    Text(currentTrack.progressStatus)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack {
                    Text("Waiting to process \(currentTrack.name)...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            VStack(spacing: 20) {
                Image(systemName: "music.note")
                    .font(.system(size: 64))
                    .foregroundColor(.gray)
                Text("No Track Selected")
                    .font(.title2)
                Text("Select a track from the library or queue to start playing.")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
