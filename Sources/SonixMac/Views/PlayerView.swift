import SwiftUI
import AVKit

struct AVPlayerViewRepresentable: NSViewRepresentable {
    var player: AVPlayer
    
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none // Hide native controls
        view.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

struct PlayerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var audioManager = AudioManager()
    
    // Gradient for the UI
    let brandGradient = LinearGradient(colors: [Color(red: 0.1, green: 0.8, blue: 0.9), Color(red: 0.5, green: 0.2, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Visualizer / Video Area
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08) // Very dark blue/black background
                
                if appState.showLyrics, let lyrics = appState.currentTrack?.lyrics, !lyrics.isEmpty {
                    ScrollView {
                        Text(lyrics)
                            .font(.title2)
                            .padding()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                    }
                } else if audioManager.hasVideo, let player = audioManager.player {
                    // Video Player using NSViewRepresentable to avoid AVKit SwiftUI bug
                    AVPlayerViewRepresentable(player: player)
                } else {
                    // Vinyl Record UI (Fallback for audio-only files)
                    ZStack {
                        // Horizontal line across the middle
                        Rectangle()
                            .fill(LinearGradient(colors: [Color.clear, Color.cyan.opacity(0.5), Color.clear], startPoint: .leading, endPoint: .trailing))
                            .frame(height: 1)
                        
                        // Vinyl Grooves
                        ForEach(1..<10) { i in
                            Circle()
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                .frame(width: CGFloat(i * 30), height: CGFloat(i * 30))
                        }
                        
                        // Vinyl Center Label
                        Circle()
                            .fill(brandGradient)
                            .frame(width: 80, height: 80)
                            .shadow(color: .purple.opacity(0.5), radius: 20, x: 0, y: 0)
                        
                        // Center Hole
                        Circle()
                            .fill(Color(red: 0.05, green: 0.05, blue: 0.08))
                            .frame(width: 15, height: 15)
                    }
                    .rotationEffect(.degrees(audioManager.isPlaying ? 360 : 0))
                    .animation(audioManager.isPlaying ? Animation.linear(duration: 4).repeatForever(autoreverses: false) : .default, value: audioManager.isPlaying)
                    
                    VStack {
                        Spacer()
                        Text(appState.currentTrack?.name ?? "Unknown Track")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.bottom, 20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Player Controls Deck
            VStack(spacing: 20) {
                // Progress Bar
                HStack {
                    Text(formatTime(audioManager.currentTime))
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Slider(value: Binding(
                        get: { audioManager.currentTime },
                        set: { newValue in
                            audioManager.seek(to: newValue)
                        }
                    ), in: 0...(audioManager.duration > 0 ? audioManager.duration : 1))
                    .tint(Color.cyan)
                    
                    Text(formatTime(audioManager.duration))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    // Volume Control
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "music.mic")
                                .foregroundColor(.cyan)
                                .font(.system(size: 10))
                                .frame(width: 14)
                            Slider(value: $audioManager.vocalsVolume, in: 0...1)
                                .frame(width: 80)
                                .tint(Color.cyan)
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "music.note")
                                .foregroundColor(.purple)
                                .font(.system(size: 10))
                                .frame(width: 14)
                            Slider(value: $audioManager.instrumentalVolume, in: 0...1)
                                .frame(width: 80)
                                .tint(Color.purple)
                        }
                    }
                    
                    Spacer()
                    
                    // Main Controls
                    HStack(spacing: 25) {
                        // Karaoke Toggle (Headphones / Mic)
                        Button(action: {
                            audioManager.playbackMode = (audioManager.playbackMode == .original) ? .karaoke : .original
                        }) {
                            Image(systemName: audioManager.playbackMode == .original ? "headphones" : "music.mic")
                                .font(.system(size: 18))
                                .foregroundColor(audioManager.playbackMode == .karaoke ? .cyan : .gray)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            appState.skipPrevious()
                        }) {
                            Image(systemName: "backward.end.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            audioManager.togglePlayPause()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(brandGradient)
                                    .frame(width: 60, height: 60)
                                    .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 0)
                                
                                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            appState.skipNext()
                        }) {
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            audioManager.isLooping.toggle()
                        }) {
                            Image(systemName: "repeat")
                                .font(.system(size: 18))
                                .foregroundColor(audioManager.isLooping ? .cyan : .gray)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    // Utility Controls (Lyrics, etc)
                    HStack(spacing: 15) {
                        Button(action: {
                            appState.showLyrics.toggle()
                        }) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 16))
                                .foregroundColor(appState.showLyrics ? .cyan : .gray)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            toggleFullScreen()
                        }) {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(25)
            .background(Color(red: 0.1, green: 0.1, blue: 0.12)) // Dark grey deck background
            .cornerRadius(20)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(Color(red: 0.05, green: 0.05, blue: 0.08)) // Match visualizer bg
        }
        .onAppear {
            loadCurrentTrack()
        }
        .onChange(of: appState.currentTrack?.id) { oldId, newId in
            loadCurrentTrack()
        }
        .alert("Audio Error", isPresented: $appState.hasError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Failed to initialize audio playback.")
        }
        .onDisappear {
            audioManager.stop()
        }
    }
    
    private func loadCurrentTrack() {
        appState.showLyrics = false
        guard let track = appState.currentTrack, 
              let instURL = track.instrumentalURL else { return }
        
        let vocURL = track.vocalsURL ?? track.originalURL
        let isVocOriginal = (track.vocalsURL == nil)
        
        audioManager.setupAndPlay(originalURL: track.originalURL, vocalsURL: vocURL, instrumentalURL: instURL, isVocalsOriginal: isVocOriginal)
    }
    
    private func formatTime(_ time: Double) -> String {
        if time.isNaN || !time.isFinite { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func toggleFullScreen() {
        if let window = NSApplication.shared.windows.first {
            window.toggleFullScreen(nil)
        }
    }
}
