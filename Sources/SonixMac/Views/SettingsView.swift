import SwiftUI

struct SettingsView: View {
    @AppStorage("backendURL") private var backendURL: String = "http://localhost:8000"
    @AppStorage("maxConcurrentTasks") private var maxConcurrentTasks: Int = 3
    @AppStorage("developerMode") private var developerMode: Bool = false

    @StateObject private var audioDeviceManager = AudioDeviceManager.shared
    @StateObject private var microphoneMonitor = MicrophoneMonitor.shared

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(header: Text("Audio Devices")) {
                    Picker("Output Device", selection: $audioDeviceManager.selectedOutputDeviceUID) {
                        ForEach(audioDeviceManager.outputDevices) { device in
                            Text(device.name).tag(device.uid)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Input Device (Microphone)", selection: $audioDeviceManager.selectedInputDeviceUID) {
                        ForEach(audioDeviceManager.inputDevices) { device in
                            Text(device.name).tag(device.uid)
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle("Live Monitoring (Hear your voice)", isOn: $microphoneMonitor.isMonitoring)
                    .padding(.top, 5)

                if microphoneMonitor.isMonitoring {
                    // Volume
                    HStack {
                        Text("Monitoring Volume")
                        Slider(
                            value: Binding(
                                get: { Double(microphoneMonitor.monitoringVolume) },
                                set: { microphoneMonitor.monitoringVolume = Float($0) }
                            ),
                            in: 0...5.0,
                            step: 0.05
                        )
                        Text("\(Int(microphoneMonitor.monitoringVolume * 100))%")
                            .frame(width: 44, alignment: .trailing)
                            .monospacedDigit()
                    }

                    Divider()

                    // Reverb toggle
                    Toggle("🎤 Singing Effects (Reverb)", isOn: Binding(
                        get: { microphoneMonitor.reverbEnabled },
                        set: { microphoneMonitor.reverbEnabled = $0 }
                    ))

                    if microphoneMonitor.reverbEnabled {
                        // Preset picker
                        Picker("Preset", selection: Binding(
                            get: { microphoneMonitor.reverbPresetIndex },
                            set: { microphoneMonitor.reverbPresetIndex = $0 }
                        )) {
                            ForEach(ReverbEffect.all) { effect in
                                Text("\(effect.emoji) \(effect.name)").tag(effect.id)
                            }
                        }
                        .pickerStyle(.menu)

                        // Wet/dry mix slider
                        HStack {
                            Text("Effect Amount")
                            Slider(
                                value: Binding(
                                    get: { Double(microphoneMonitor.reverbMix) },
                                    set: { microphoneMonitor.reverbMix = Float($0) }
                                ),
                                in: 0...100,
                                step: 1
                            )
                            Text("\(Int(microphoneMonitor.reverbMix))%")
                                .frame(width: 40, alignment: .trailing)
                                .monospacedDigit()
                        }
                    }
                }

                let isBluetooth = audioDeviceManager.outputDevices
                    .first(where: { $0.uid == audioDeviceManager.selectedOutputDeviceUID })
                    .map { $0.name.contains("Buds") || $0.name.contains("AirPods") || $0.name.contains("Bluetooth") || $0.name.contains("BT") } ?? false

                if isBluetooth && microphoneMonitor.isMonitoring {
                    Text("⚠️ Bluetooth headphones have 40–200ms inherent codec delay. For near-zero latency, use wired headphones.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.bottom, 10)
                } else {
                    Text("Hear your microphone feedback through your output device in real-time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 10)
                }
                }

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

                    Text("If you are hosting this frontend on Vercel or locally, enter the public URL of your Node.js backend (e.g. using ngrok) here to connect them. Leave as **http://localhost:8000** for local development.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    TextField("Local Backend Folder Path", text: $backendFolderPath)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        if BackendManager.shared.isRunning {
                            Button("Stop Backend Server") { BackendManager.shared.stopBackend() }
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

                Section(header: Text("Developer")) {
                    Toggle("Developer Mode (show console)", isOn: $developerMode)
                }

                Section(header: Text("About")) {
                    Text("App Version: \(AppConfig.version)")
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .onReceive(BackendManager.shared.$isRunning) { _ in }

            if developerMode {
                ConsoleView()
                    .frame(minHeight: 200, maxHeight: 300)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .frame(minWidth: 600, minHeight: developerMode ? 720 : 500)
    }

    @AppStorage("backendFolderPath") private var backendFolderPath: String = "/Users/dannyphang/Documents/GitHub/vocal-remover-angular"
}
