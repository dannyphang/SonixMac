import SwiftUI
import Foundation

enum AppScreen {
    case upload
    case processing
    case player
}

@MainActor
class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .upload
    
    // Processing State
    @Published var processingStatus: String = "Initializing..."
    @Published var isTranscribing: Bool = false
    
    // Results
    @Published var songName: String = ""
    @Published var vocalsPath: URL? = nil
    @Published var instrumentalPath: URL? = nil
    @Published var lyrics: String = ""
    @Published var selectedFileURL: URL? = nil
    // Library & Queue
    @Published var library: [Track] = []
    @Published var queue: [Track] = []
    @Published var processingQueue: [Track] = []
    @Published var currentTrackIndex: Int? = nil
    @Published var searchText: String = ""
    
    // Internal task tracking
    var processingTasks: [UUID: Task<Void, Never>] = [:]
    
    // UI State
    @Published var isHovering: Bool = false
    @Published var isAnimating: Bool = false
    @Published var hasError: Bool = false
    
    // Error State
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var showLyrics: Bool = false
    
    // Computed property for the currently playing track
    var currentTrack: Track? {
        guard let index = currentTrackIndex, index >= 0, index < queue.count else { return nil }
        return queue[index]
    }
    
    // Status Bar
    @Published var statusBarMessage: String = "Ready"
    @Published var statusBarIcon: String = "checkmark.circle"
    private var statusClearTask: Task<Void, Never>? = nil
    
    func showStatus(_ message: String, icon: String = "info.circle") {
        statusBarMessage = message
        statusBarIcon = icon
        
        statusClearTask?.cancel()
        statusClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            if !Task.isCancelled {
                self.statusBarMessage = "Ready"
                self.statusBarIcon = "checkmark.circle"
            }
        }
    }
    
    func reset() {
        currentScreen = .upload
        processingStatus = "Initializing..."
        isTranscribing = false
        songName = ""
        vocalsPath = nil
        instrumentalPath = nil
        lyrics = ""
        showError = false
        errorMessage = ""
        selectedFileURL = nil
    }
    
    func addToQueue(_ track: Track) {
        queue.append(track)
        if currentTrackIndex == nil {
            currentTrackIndex = 0
        }
        showStatus("Added \(track.name) to play queue", icon: "text.badge.plus")
    }
    
    func addToProcessingQueue(_ track: Track) {
        if !processingQueue.contains(where: { $0.id == track.id }) {
            processingQueue.append(track)
            showStatus("Added \(track.name) to processing queue", icon: "waveform.badge.plus")
        }
    }
    
    func addProcessedTrackToQueue(trackId: UUID) {
        guard let index = processingQueue.firstIndex(where: { $0.id == trackId }) else { return }
        let track = processingQueue[index]
        addToQueue(track)
        processingQueue.remove(at: index)
    }
    
    func cancelProcessing(trackId: UUID) {
        if let task = processingTasks[trackId] {
            task.cancel()
            processingTasks.removeValue(forKey: trackId)
        }
        if let index = processingQueue.firstIndex(where: { $0.id == trackId }) {
            if processingQueue[index].progressStatus == "Done" {
                // If it was done and we clicked clear
                processingQueue.remove(at: index)
            } else {
                processingQueue[index].isProcessing = false
                processingQueue[index].progressStatus = "Canceled"
            }
        }
    }
    
    func clearFromProcessingQueue(trackId: UUID) {
        if let index = processingQueue.firstIndex(where: { $0.id == trackId }) {
            processingQueue.remove(at: index)
        }
    }
    
    func clearAllProcessing() {
        for (_, task) in processingTasks {
            task.cancel()
        }
        processingTasks.removeAll()
        processingQueue.removeAll()
    }
    
    func processAllUnsplit() {
        var count = 0
        for track in library where !track.isSeparated {
            if !processingQueue.contains(where: { $0.id == track.id }) {
                processingQueue.append(track)
                count += 1
            }
        }
        if count > 0 {
            showStatus("Added \(count) tracks to processing queue", icon: "waveform.badge.plus")
        }
    }
    
    func addFolderToLibrary(url: URL) {
        do {
            sourceFolderPath = url.path
            library.removeAll()
            
            let files = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            let audioFiles = files.filter { ["mp3", "wav", "m4a", "aac", "mp4"].contains($0.pathExtension.lowercased()) }
            
            for fileURL in audioFiles {
                var track = Track(name: fileURL.lastPathComponent, originalURL: fileURL)
                
                // Check if already splitted in the output folder
                if !outputFolderPath.isEmpty {
                    let outputDir = URL(fileURLWithPath: outputFolderPath)
                    let songNameStr = fileURL.deletingPathExtension().lastPathComponent
                    let songDir = outputDir.appendingPathComponent(songNameStr)
                    
                    let accompanimentURL = songDir.appendingPathComponent("accompaniment.wav")
                    let vocalsURL = songDir.appendingPathComponent("vocals.wav")
                    let lyricsURL = songDir.appendingPathComponent("lyrics.lrc")
                    
                    if FileManager.default.fileExists(atPath: accompanimentURL.path) {
                        track.instrumentalURL = accompanimentURL
                        if FileManager.default.fileExists(atPath: vocalsURL.path) {
                            track.vocalsURL = vocalsURL
                        }
                        if FileManager.default.fileExists(atPath: lyricsURL.path),
                           let lyricsText = try? String(contentsOf: lyricsURL) {
                            track.lyrics = lyricsText
                        }
                    }
                }
                
                library.append(track)
            }
        } catch {
            print("Failed to read directory: \(error)")
        }
    }
    
    func loadSavedSourceFolder() {
        if !sourceFolderPath.isEmpty {
            let url = URL(fileURLWithPath: sourceFolderPath)
            addFolderToLibrary(url: url)
        }
    }
    
    // Background Processing Pipeline
    func startQueueProcessor() {
        Task {
            while true {
                while processingTasks.count < maxConcurrentTasks {
                    if let index = processingQueue.firstIndex(where: { !$0.isSeparated && !$0.isProcessing && $0.progressStatus != "Canceled" && $0.progressStatus != "Failed" && $0.progressStatus != "Done" }) {
                        // Mark it as processing immediately so the next iteration doesn't pick it up
                        processingQueue[index].isProcessing = true
                        processTrack(at: index)
                    } else {
                        break
                    }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Poll every second
            }
        }
    }
    
    @AppStorage("maxConcurrentTasks") var maxConcurrentTasks: Int = 3
    @AppStorage("replicateToken") var token: String = ""
    @AppStorage("selectedEngine") var engine: String = "local_demucs"
    @AppStorage("sourceFolderPath") var sourceFolderPath: String = ""
    @AppStorage("outputFolderPath") var outputFolderPath: String = ""
    
    private func processTrack(at index: Int) {
        guard index < processingQueue.count else { return }
        
        let trackID = processingQueue[index].id
        
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            
            guard let i = self.processingQueue.firstIndex(where: { $0.id == trackID }) else { return }
            
            let url = self.processingQueue[i].originalURL
            
            self.processingQueue[i].isProcessing = true
            self.processingQueue[i].progressStatus = "Starting..."
            
            do {
                let response = try await APIClient.shared.separate(fileURL: url, engine: self.engine, token: self.token) { status in
                    DispatchQueue.main.async {
                        if let currentI = self.processingQueue.firstIndex(where: { $0.id == trackID }) {
                            self.processingQueue[currentI].progressStatus = status
                        }
                    }
                }
                
                if Task.isCancelled { return }
                
                if let currentI = self.processingQueue.firstIndex(where: { $0.id == trackID }) {
                    if let voc = response.vocals, let inst = response.instrumental,
                       let vocURL = APIClient.shared.getFullURL(from: voc),
                       let instURL = APIClient.shared.getFullURL(from: inst) {
                        
                        var finalVocURL = vocURL
                        var finalInstURL = instURL
                        
                        // Copy to Output Folder if configured
                        if !self.outputFolderPath.isEmpty {
                            let outputDir = URL(fileURLWithPath: self.outputFolderPath)
                            let songNameStr = self.processingQueue[currentI].originalURL.deletingPathExtension().lastPathComponent
                            let songDir = outputDir.appendingPathComponent(songNameStr)
                            
                            do {
                                if !FileManager.default.fileExists(atPath: songDir.path) {
                                    try FileManager.default.createDirectory(at: songDir, withIntermediateDirectories: true)
                                }
                                
                                let newVocURL = songDir.appendingPathComponent("vocals.wav")
                                let newInstURL = songDir.appendingPathComponent("accompaniment.wav")
                                
                                // Download/copy from the local backend to the output dir
                                if let vocData = try? Data(contentsOf: vocURL) {
                                    try? vocData.write(to: newVocURL)
                                    finalVocURL = newVocURL
                                }
                                if let instData = try? Data(contentsOf: instURL) {
                                    try? instData.write(to: newInstURL)
                                    finalInstURL = newInstURL
                                }
                            } catch {
                                print("Failed to save to output folder: \(error)")
                            }
                        }
                        
                        self.processingQueue[currentI].vocalsURL = finalVocURL
                        self.processingQueue[currentI].instrumentalURL = finalInstURL
                        
                        // Also update in library
                        if let libIndex = self.library.firstIndex(where: { $0.originalURL == url }) {
                            self.library[libIndex].vocalsURL = finalVocURL
                            self.library[libIndex].instrumentalURL = finalInstURL
                        }
                    }
                    self.processingQueue[currentI].isProcessing = false
                    self.processingQueue[currentI].progressStatus = "Done"
                    self.showStatus("\(self.processingQueue[currentI].name) is successfully processed", icon: "checkmark.circle.fill")
                }
                self.processingTasks.removeValue(forKey: trackID)
            } catch is CancellationError {
                if let currentI = self.processingQueue.firstIndex(where: { $0.id == trackID }) {
                    self.processingQueue[currentI].isProcessing = false
                    self.processingQueue[currentI].progressStatus = "Canceled"
                }
            } catch {
                if let currentI = self.processingQueue.firstIndex(where: { $0.id == trackID }) {
                    self.processingQueue[currentI].isProcessing = false
                    self.processingQueue[currentI].progressStatus = "Failed"
                    self.errorMessage = "Failed to separate \(self.processingQueue[currentI].name): \(error.localizedDescription)"
                    self.showError = true
                }
                self.processingTasks.removeValue(forKey: trackID)
            }
        }
        
        processingTasks[trackID] = task
    }
    
    func removeFromQueue(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        queue.remove(at: index)
        
        if let current = currentTrackIndex {
            if index < current {
                currentTrackIndex = current - 1
            } else if index == current {
                if queue.isEmpty {
                    currentTrackIndex = nil
                } else if current >= queue.count {
                    currentTrackIndex = queue.count - 1
                }
            }
        }
    }
    
    func skipNext() {
        guard let current = currentTrackIndex else { return }
        if current < queue.count {
            queue.remove(at: current)
            if current >= queue.count {
                if queue.isEmpty {
                    currentTrackIndex = nil
                } else {
                    currentTrackIndex = queue.count - 1
                }
            }
        }
    }
    
    func skipPrevious() {
        guard let current = currentTrackIndex else { return }
        if current - 1 >= 0 {
            currentTrackIndex = current - 1
        }
    }
}
