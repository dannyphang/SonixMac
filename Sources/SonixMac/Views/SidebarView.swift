import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var backend = BackendManager.shared
    @AppStorage("backendFolderPath") var backendFolderPath: String = "/Users/dannyphang/Documents/GitHub/vocal-remover-angular"
    
    var filteredLibrary: [Track] {
        if appState.searchText.isEmpty { return appState.library }
        return appState.library.filter { $0.name.localizedCaseInsensitiveContains(appState.searchText) }
    }
    
    var filteredProcessing: [Track] {
        if appState.searchText.isEmpty { return appState.processingQueue }
        return appState.processingQueue.filter { $0.name.localizedCaseInsensitiveContains(appState.searchText) }
    }
    
    var filteredQueue: [Track] {
        if appState.searchText.isEmpty { return appState.queue }
        return appState.queue.filter { $0.name.localizedCaseInsensitiveContains(appState.searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                Section(header: Text("AI Audio Splitter")) {
                    Button(action: selectSourceFolder) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            VStack(alignment: .leading) {
                                Text("Source Media Folder")
                                Text(appState.sourceFolderPath.isEmpty ? "Not Selected" : URL(fileURLWithPath: appState.sourceFolderPath).lastPathComponent)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    
                    Button(action: selectOutputFolder) {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                            VStack(alignment: .leading) {
                                Text("Output Folder (Stems)")
                                Text(appState.outputFolderPath.isEmpty ? "Select Output Folder" : URL(fileURLWithPath: appState.outputFolderPath).lastPathComponent)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    
                    Picker("Engine", selection: $appState.engine) {
                        Text("Local AI (Meta Demucs)").tag("local_demucs")
                        Text("Replicate Cloud").tag("replicate")
                    }
                    .pickerStyle(.menu)
                    .padding(.vertical, 4)
                }
                
                Section(header: HStack {
                    Text("Play Queue")
                    Spacer()
                    if !appState.queue.isEmpty {
                        Button(action: {
                            if let current = appState.currentTrackIndex, current < appState.queue.count {
                                let currentTrack = appState.queue.remove(at: current)
                                appState.queue.shuffle()
                                appState.queue.insert(currentTrack, at: 0)
                                appState.currentTrackIndex = 0
                            } else {
                                appState.queue.shuffle()
                                appState.currentTrackIndex = appState.queue.isEmpty ? nil : 0
                            }
                        }) {
                            Image(systemName: "shuffle")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Shuffle Queue")
                    }
                }.padding(.trailing, 8)) {
                    if appState.queue.isEmpty {
                        Text(appState.searchText.isEmpty ? "Queue is empty" : "No results")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(Array(appState.queue.enumerated()), id: \.element.id) { index, track in
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.gray.opacity(0.5))
                                    .font(.system(size: 14))
                                    .padding(.trailing, 4)
                                    
                                if appState.currentTrackIndex == index {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(.blue)
                                        .frame(width: 16)
                                } else {
                                    Spacer().frame(width: 16)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(track.name)
                                        .lineLimit(1)
                                    
                                    if track.isSeparated {
                                        Text("Ready")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else {
                                        Text("Not Separated")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    appState.currentTrackIndex = index
                                }
                                
                                Spacer()
                                Button(action: {
                                    appState.removeFromQueue(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        }
                        .onMove { source, destination in
                            appState.queue.move(fromOffsets: source, toOffset: destination)
                            if let current = appState.currentTrackIndex {
                                let moved = source.contains(current)
                                if moved {
                                    var dest = destination
                                    if destination > current { dest -= 1 }
                                    appState.currentTrackIndex = dest
                                } else {
                                    let currentTrack = appState.queue[current]
                                    appState.currentTrackIndex = appState.queue.firstIndex(where: { $0.id == currentTrack.id })
                                }
                            }
                        }
                    }
                }
                
                Section(header: HStack {
                    Text("Local Library")
                    Spacer()
                    if appState.library.contains(where: { !$0.isSeparated }) {
                        Button("Process All") {
                            appState.processAllUnsplit()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.orange)
                        .font(.caption)
                    }
                }.padding(.trailing, 8)) {
                    ForEach(filteredLibrary) { track in
                        HStack {
                            if track.isSeparated {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 14))
                            }
                            
                            Text(track.name)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            if track.isSeparated {
                                Button(action: {
                                    appState.addToQueue(track)
                                }) {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                .help("Add to Queue")
                            } else {
                                Button(action: {
                                    appState.addToProcessingQueue(track)
                                }) {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(.orange)
                                }
                                .buttonStyle(.plain)
                                .help("Download / Separate")
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                Section(header: HStack {
                    Text("Processing")
                    Spacer()
                    if !appState.processingQueue.isEmpty {
                        Button("Clear All") {
                            appState.clearAllProcessing()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                }.padding(.trailing, 8)) {
                    if filteredProcessing.isEmpty {
                        Text(appState.searchText.isEmpty ? "No processing tasks" : "No results")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(filteredProcessing) { track in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(track.name)
                                        .lineLimit(1)
                                    
                                    if track.isProcessing {
                                        Text(track.progressStatus)
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    } else if track.progressStatus == "Done" {
                                        Text("Done")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else if track.progressStatus == "Failed" || track.progressStatus == "Canceled" {
                                        Text(track.progressStatus)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    } else {
                                        Text("Queued for processing")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if track.progressStatus == "Done" {
                                    Button(action: {
                                        appState.addProcessedTrackToQueue(trackId: track.id)
                                    }) {
                                        Image(systemName: "plus.circle")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Add to Queue")
                                    
                                    Button(action: {
                                        appState.clearFromProcessingQueue(trackId: track.id)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.gray)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Clear")
                                    .padding(.leading, 4)
                                } else {
                                    Button(action: {
                                        if track.progressStatus == "Failed" || track.progressStatus == "Canceled" {
                                            appState.clearFromProcessingQueue(trackId: track.id)
                                        } else {
                                            appState.cancelProcessing(trackId: track.id)
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                    .buttonStyle(.plain)
                                    .help(track.progressStatus == "Failed" || track.progressStatus == "Canceled" ? "Clear" : "Cancel")
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                


            }
            .listStyle(.sidebar)
            .searchable(text: $appState.searchText, placement: .sidebar)
            
        }
        .frame(minWidth: 260)
    }
    
    
    private func selectSourceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            appState.addFolderToLibrary(url: url)
        }
    }
    
    private func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the folder where separated stems will be saved."
        
        if panel.runModal() == .OK, let url = panel.url {
            appState.outputFolderPath = url.path
        }
    }
}
