import Foundation
import AVFoundation
import CoreAudio

@MainActor
public class MicrophoneMonitor: ObservableObject {
    public static let shared = MicrophoneMonitor()

    private var audioEngine: AVAudioEngine?
    private var gainNode: AVAudioMixerNode?
    private var reverbNode: AVAudioUnitReverb?

    // Volume
    private var _monitoringVolume: Float = 1.5 {
        willSet { objectWillChange.send() }
        didSet { gainNode?.outputVolume = _monitoringVolume }
    }
    public var monitoringVolume: Float {
        get { _monitoringVolume }
        set { _monitoringVolume = min(max(newValue, 0), 5.0) }
    }

    // Reverb
    private var _reverbEnabled = false {
        willSet { objectWillChange.send() }
        didSet { reverbNode?.wetDryMix = _reverbEnabled ? _reverbMix : 0 }
    }
    public var reverbEnabled: Bool {
        get { _reverbEnabled }
        set { _reverbEnabled = newValue }
    }

    private var _reverbMix: Float = 40 {   // 0–100 wet/dry
        willSet { objectWillChange.send() }
        didSet { if _reverbEnabled { reverbNode?.wetDryMix = _reverbMix } }
    }
    public var reverbMix: Float {
        get { _reverbMix }
        set { _reverbMix = min(max(newValue, 0), 100) }
    }

    // Preset index into ReverbEffect.all
    private var _reverbPresetIndex: Int = 0 {
        willSet { objectWillChange.send() }
        didSet {
            if let node = reverbNode, _reverbPresetIndex < ReverbEffect.all.count {
                node.loadFactoryPreset(ReverbEffect.all[_reverbPresetIndex].preset)
            }
        }
    }
    public var reverbPresetIndex: Int {
        get { _reverbPresetIndex }
        set { _reverbPresetIndex = min(max(newValue, 0), ReverbEffect.all.count - 1) }
    }

    // Separate backing store avoids @Published on computed property (compiler error)
    private var _isMonitoring = false {
        willSet { objectWillChange.send() }
    }
    public var isMonitoring: Bool {
        get { _isMonitoring }
        set {
            guard newValue != _isMonitoring else { return }
            if newValue {
                requestPermissionAndStart()
            } else {
                _isMonitoring = false
                stopEngine()
            }
        }
    }

    private init() {
        NotificationCenter.default.addObserver(
            forName: .audioDeviceChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard self?._isMonitoring == true else { return }
                self?.stopEngine()
                self?.startEngine()
            }
        }
    }

    private func requestPermissionAndStart() {
        if #available(macOS 14.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.startEngine()
                    } else {
                        AppLogger.shared.log("⚠️ Microphone permission denied.")
                        self?._isMonitoring = false
                    }
                }
            }
        } else {
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                startEngine()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                    Task { @MainActor in
                        if granted {
                            self?.startEngine()
                        } else {
                            AppLogger.shared.log("⚠️ Microphone permission denied.")
                            self?._isMonitoring = false
                        }
                    }
                }
            default:
                AppLogger.shared.log("⚠️ Microphone access not authorized. Please enable in System Settings → Privacy → Microphone.")
                _isMonitoring = false
            }
        }
    }

    private func startEngine() {
        let engine = AVAudioEngine()
        audioEngine = engine

        let inputUID = AudioDeviceManager.shared.selectedInputDeviceUID
        let outputUID = AudioDeviceManager.shared.selectedOutputDeviceUID

        // Set system default devices via CoreAudio — AVAudioEngine uses them automatically.
        // auAudioUnit.setDeviceID() causes OSStatus -10851 on macOS when called pre-connect.
        var inputID = kAudioObjectUnknown as AudioDeviceID
        var outputID = kAudioObjectUnknown as AudioDeviceID

        if !inputUID.isEmpty {
            inputID = getAudioDeviceID(from: inputUID)
            AppLogger.shared.log("🎙️ Setting system default input → ID \(inputID) (\(inputUID))")
            setDefaultDevice(inputID, isInput: true)
        }
        if !outputUID.isEmpty {
            outputID = getAudioDeviceID(from: outputUID)
            AppLogger.shared.log("🔊 Setting system default output → ID \(outputID) (\(outputUID))")
            setDefaultDevice(outputID, isInput: false)
            // Bluetooth devices have inherent codec latency (40–200ms) that buffer tuning cannot remove
            if outputUID.contains("Bluetooth") || outputUID.contains("BT") ||
               AudioDeviceManager.shared.outputDevices.first(where: { $0.uid == outputUID })?.name.contains("Buds") == true ||
               AudioDeviceManager.shared.outputDevices.first(where: { $0.uid == outputUID })?.name.contains("AirPods") == true {
                AppLogger.shared.log("⚠️ Bluetooth output detected — expect 40–200ms inherent codec delay that cannot be reduced.")
            }
        }

        // Reduce I/O buffer to 128 frames (~3ms at 44.1kHz) for lowest latency
        let bufferFrames: UInt32 = 128
        if inputID != kAudioObjectUnknown { setBufferSize(bufferFrames, deviceID: inputID) }
        if outputID != kAudioObjectUnknown { setBufferSize(bufferFrames, deviceID: outputID) }
        AppLogger.shared.log("⏱️ I/O buffer set to \(bufferFrames) frames")

        do {
            let inputNode = engine.inputNode
            let gainMixer = AVAudioMixerNode()
            let mainMixer = engine.mainMixerNode
            // Use the mic's native format for the first hop only.
            // nil format lets AVAudioEngine auto-negotiate stereo for subsequent nodes
            // (AVAudioUnitReverb requires stereo; passing mono format crashes).
            let micFormat = inputNode.outputFormat(forBus: 0)
            AppLogger.shared.log("🎛️ Input format: \(micFormat)")

            engine.attach(gainMixer)
            let reverb = AVAudioUnitReverb()
            reverb.loadFactoryPreset(ReverbEffect.all[_reverbPresetIndex].preset)
            reverb.wetDryMix = _reverbEnabled ? _reverbMix : 0
            engine.attach(reverb)

            engine.connect(inputNode, to: gainMixer, format: micFormat)
            engine.connect(gainMixer, to: reverb, format: nil)   // auto stereo conversion
            engine.connect(reverb, to: mainMixer, format: nil)   // auto stereo conversion

            gainMixer.outputVolume = _monitoringVolume
            gainNode = gainMixer
            reverbNode = reverb
            engine.prepare()
            try engine.start()


            _isMonitoring = true
            AppLogger.shared.log("✅ Live monitoring started.")
        } catch {
            AppLogger.shared.log("❌ Live monitoring failed: \(error.localizedDescription)")
            _isMonitoring = false
            audioEngine = nil
        }
    }

    private func setDefaultDevice(_ deviceID: AudioDeviceID, isInput: Bool) {
        guard deviceID != kAudioObjectUnknown else { return }
        var id = deviceID
        var addr = AudioObjectPropertyAddress(
            mSelector: isInput ? kAudioHardwarePropertyDefaultInputDevice
                               : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr,
            0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id
        )
        if status != noErr {
            AppLogger.shared.log("⚠️ Could not set default device: OSStatus \(status)")
        }
    }

    private func setBufferSize(_ frames: UInt32, deviceID: AudioDeviceID) {
        var frames = frames
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            deviceID, &addr, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &frames
        )
        if status != noErr {
            AppLogger.shared.log("⚠️ Could not set buffer size on device \(deviceID): OSStatus \(status)")
        }
    }

    private func stopEngine() {
        audioEngine?.stop()
        audioEngine = nil
        gainNode = nil
        reverbNode = nil
        AppLogger.shared.log("⏹️ Live monitoring stopped.")
    }

    private func getAudioDeviceID(from uid: String) -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize
        ) == noErr else { return kAudioObjectUnknown }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs
        )

        for id in deviceIDs {
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var currentUID: Unmanaged<CFString>?
            var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            AudioObjectGetPropertyData(id, &uidAddress, 0, nil, &uidSize, &currentUID)
            if let uidString = currentUID?.takeRetainedValue() as String?, uidString == uid {
                return id
            }
        }
        return kAudioObjectUnknown
    }
}
