import Foundation
import Combine

class BackendManager: ObservableObject {
    static let shared = BackendManager()
    
    @Published var isRunning = false
    @Published var logs: String = ""
    private var process: Process?
    
    func startBackend(at path: String) {
        guard !isRunning else { return }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        
        // Ensure common node installation paths are in PATH, navigate to the folder, and run server.js
        task.arguments = ["-c", "export PATH=\"$PATH:/usr/local/bin:/opt/homebrew/bin\"; cd \"\(path)\" && /usr/local/bin/node server.js"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.count > 0, let str = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.logs.append(str)
                    // Keep logs from growing infinitely
                    if self?.logs.count ?? 0 > 10000 {
                        self?.logs = String(self?.logs.suffix(10000) ?? "")
                    }
                }
            }
        }
        
        task.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }
        
        do {
            try task.run()
            DispatchQueue.main.async {
                self.isRunning = true
                self.process = task
            }
        } catch {
            print("Failed to start backend: \(error)")
        }
    }
    
    func stopBackend() {
        process?.terminate()
        process = nil
        isRunning = false
    }
}
