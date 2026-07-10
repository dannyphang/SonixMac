import SwiftUI
import UniformTypeIdentifiers

struct UploadView: View {
    @EnvironmentObject var appState: AppState

    @AppStorage("replicateToken") private var token: String = ""
    @AppStorage("selectedEngine") private var engine: String = "local_demucs"
    

    var body: some View {
        VStack(spacing: 30) {
            Text("Sonix")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            
            Text("Vocal Remover & Stem Splitter")
                .font(.title2)
                .foregroundColor(.secondary)
            
            // Drag and Drop Zone
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(appState.isHovering ? Color.blue : Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 3, dash: [10]))
                    .background(appState.isHovering ? Color.blue.opacity(0.1) : Color.clear)
                    .frame(height: 200)
                
                VStack(spacing: 15) {
                    Image(systemName: appState.selectedFileURL != nil ? "music.note.list" : "arrow.up.doc")
                        .font(.system(size: 40))
                        .foregroundColor(appState.isHovering ? .blue : .gray)
                    
                    if let url = appState.selectedFileURL {
                        Text(url.lastPathComponent)
                            .font(.headline)
                        Button("Remove") {
                            appState.selectedFileURL = nil
                        }
                        .buttonStyle(.link)
                    } else {
                        Text("Drag & Drop audio file here")
                            .font(.headline)
                        Text("or click to browse (.mp3, .wav)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onDrop(of: [UTType.audio], isTargeted: $appState.isHovering) { providers in
                guard let provider = providers.first else { return false }
                provider.loadItem(forTypeIdentifier: UTType.audio.identifier, options: nil) { item, error in
                    if let url = item as? URL {
                        DispatchQueue.main.async {
                            appState.selectedFileURL = url
                        }
                    }
                }
                return true
            }
            .onTapGesture {
                openFilePanel()
            }
            
            // Options
            VStack(alignment: .leading, spacing: 15) {
                Picker("AI Engine", selection: $engine) {
                    Text("Local Offline DSP (Fast)").tag("ffmpeg_dsp")
                    Text("Local Demucs (Slow, Quality)").tag("local_demucs")
                    Text("Replicate Cloud (Fast, Quality)").tag("cloud_replicate")
                }
                .pickerStyle(.radioGroup)
                
                if engine == "cloud_replicate" {
                    SecureField("Replicate API Token", text: $token)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            Button(action: startSeparation) {
                Text("Separate Stems")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(appState.selectedFileURL != nil ? Color.blue : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(appState.selectedFileURL == nil)
            .buttonStyle(.plain)
        }
        .padding(40)
        .alert("Error", isPresented: $appState.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.errorMessage)
        }
    }
    
    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK {
            appState.selectedFileURL = panel.url
        }
    }
    
    private func startSeparation() {
        guard let url = appState.selectedFileURL else { return }
        if engine == "cloud_replicate" && token.isEmpty {
            appState.errorMessage = "Please enter your Replicate API Token."
            appState.showError = true
            return
        }
        
        appState.songName = url.lastPathComponent
        appState.currentScreen = .processing
        
        Task {
            do {
                let response = try await APIClient.shared.separate(fileURL: url, engine: engine, token: token) { status in
                    DispatchQueue.main.async {
                        appState.processingStatus = status
                    }
                }
                
                // Switch to player when done
                DispatchQueue.main.async {
                    if let voc = response.vocals, let inst = response.instrumental,
                       let vocURL = APIClient.shared.getFullURL(from: voc),
                       let instURL = APIClient.shared.getFullURL(from: inst) {
                        appState.vocalsPath = vocURL
                        appState.instrumentalPath = instURL
                        appState.currentScreen = .player
                        
                        // Kick off transcription in background
                        transcribe(url: url)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    appState.errorMessage = error.localizedDescription
                    appState.showError = true
                    appState.currentScreen = .upload
                }
            }
        }
    }
    
    private func transcribe(url: URL) {
        appState.isTranscribing = true
        Task {
            do {
                let response = try await APIClient.shared.transcribe(fileURL: url)
                DispatchQueue.main.async {
                    if let lyrics = response.syncedLyrics {
                        appState.lyrics = lyrics
                    }
                    appState.isTranscribing = false
                }
            } catch {
                DispatchQueue.main.async {
                    appState.isTranscribing = false
                    print("Transcription failed: \(error)")
                }
            }
        }
    }
}
