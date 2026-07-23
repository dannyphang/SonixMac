import Foundation
import CoreAudio
import Combine

public struct AudioDevice: Identifiable, Hashable {
    public let id: AudioDeviceID
    public let name: String
    public let uid: String
    public let isInput: Bool
    public let isOutput: Bool
}

extension Notification.Name {
    static let audioDeviceChanged = Notification.Name("audioDeviceChanged")
}

@MainActor
public class AudioDeviceManager: ObservableObject {
    public static let shared = AudioDeviceManager()
    
    @Published public var inputDevices: [AudioDevice] = []
    @Published public var outputDevices: [AudioDevice] = []
    
    @Published public var selectedInputDeviceUID: String = "" {
        didSet {
            UserDefaults.standard.set(selectedInputDeviceUID, forKey: "selectedInputDeviceUID")
            NotificationCenter.default.post(name: .audioDeviceChanged, object: nil)
        }
    }
    
    @Published public var selectedOutputDeviceUID: String = "" {
        didSet {
            UserDefaults.standard.set(selectedOutputDeviceUID, forKey: "selectedOutputDeviceUID")
            NotificationCenter.default.post(name: .audioDeviceChanged, object: nil)
        }
    }
    
    private init() {
        self.selectedInputDeviceUID = UserDefaults.standard.string(forKey: "selectedInputDeviceUID") ?? ""
        self.selectedOutputDeviceUID = UserDefaults.standard.string(forKey: "selectedOutputDeviceUID") ?? ""
        refreshDevices()
        setupDeviceListener()
    }
    
    private func setupDeviceListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, DispatchQueue.main) { [weak self] (_, _) in
            Task { @MainActor in
                self?.refreshDevices()
            }
        }
    }
    
    public func refreshDevices() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        
        if status != noErr { return }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)
        
        var inputs: [AudioDevice] = []
        var outputs: [AudioDevice] = []
        
        for id in deviceIDs {
            let name = getDeviceName(id)
            let uid = getDeviceUID(id)
            
            let inputChannels = getChannelCount(id, scope: kAudioObjectPropertyScopeInput)
            let outputChannels = getChannelCount(id, scope: kAudioObjectPropertyScopeOutput)
            
            let isInput = inputChannels > 0
            let isOutput = outputChannels > 0
            
            let device = AudioDevice(id: id, name: name, uid: uid, isInput: isInput, isOutput: isOutput)
            
            if isInput { inputs.append(device) }
            if isOutput { outputs.append(device) }
        }
        
        self.inputDevices = inputs
        self.outputDevices = outputs
        
        // Ensure selections are valid, fallback to system defaults if needed
        if !inputs.contains(where: { $0.uid == selectedInputDeviceUID }) {
            selectedInputDeviceUID = getDefaultDeviceUID(isInput: true) ?? ""
        }
        if !outputs.contains(where: { $0.uid == selectedOutputDeviceUID }) {
            selectedOutputDeviceUID = getDefaultDeviceUID(isInput: false) ?? ""
        }
    }
    
    private func getDeviceName(_ id: AudioDeviceID) -> String {
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, &name)
        return status == noErr ? (name?.takeRetainedValue() as String? ?? "Unknown Device") : "Unknown Device"
    }
    
    private func getDeviceUID(_ id: AudioDeviceID) -> String {
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: Unmanaged<CFString>?
        var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(id, &uidAddress, 0, nil, &uidSize, &uid)
        return status == noErr ? (uid?.takeRetainedValue() as String? ?? "") : ""
    }
    
    private func getChannelCount(_ id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(id, &address, 0, nil, &dataSize)
        if status != noErr { return 0 }
        
        let bufferListPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(dataSize))
        defer { bufferListPointer.deallocate() }
        
        status = AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, bufferListPointer)
        if status != noErr { return 0 }
        
        var totalChannels = 0
        bufferListPointer.withMemoryRebound(to: AudioBufferList.self, capacity: 1) { ptr in
            let mBuffers = UnsafeMutableAudioBufferListPointer(ptr)
            for buffer in mBuffers {
                totalChannels += Int(buffer.mNumberChannels)
            }
        }
        
        return totalChannels
    }
    
    private func getDefaultDeviceUID(isInput: Bool) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: isInput ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        if status == noErr {
            return getDeviceUID(deviceID)
        }
        return nil
    }
}
