import SwiftUI

struct SettingsView: View {
    @AppStorage("backendURL") private var backendURL: String = "http://localhost:8000"
    @AppStorage("maxConcurrentTasks") private var maxConcurrentTasks: Int = 3
    
    var body: some View {
        Form {
            Section(header: Text("Processing Configuration")) {
                Stepper(value: $maxConcurrentTasks, in: 1...10) {
                    Text("Max Concurrent Processing: \(maxConcurrentTasks)")
                }
                
                Text("Controls how many songs can be processed at the same time.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)
            }
            
            Section(header: Text("Backend Configuration")) {
                TextField("Backend API Server URL", text: $backendURL)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 400)
                
                Text("If you are hosting this frontend on Vercel or locally, enter the public URL of your Node.js backend (e.g. using ngrok) here to connect them. Leave as **http://localhost:8000** for local development.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider()
                
                TextField("Local Backend Folder Path", text: $backendFolderPath)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 400)
                
                HStack {
                    if BackendManager.shared.isRunning {
                        Button("Stop Backend Server") {
                            BackendManager.shared.stopBackend()
                        }
                        .foregroundColor(.red)
                        
                        Text("Running ✅").foregroundColor(.green).font(.caption)
                    } else {
                        Button("Start Backend Server") {
                            BackendManager.shared.startBackend(at: backendFolderPath)
                        }
                        .foregroundColor(.accentColor)
                        
                        Text("Stopped 🔴").foregroundColor(.red).font(.caption)
                    }
                }
            }
            .padding(.bottom, 10)
            
            Section(header: Text("About")) {
                Text("App Version: \(AppConfig.version)")
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 500, height: 400)
        .onReceive(BackendManager.shared.$isRunning) { _ in
            // Force view update when running state changes
        }
    }
    
    @AppStorage("backendFolderPath") private var backendFolderPath: String = "/Users/dannyphang/Documents/GitHub/vocal-remover-angular"
}
