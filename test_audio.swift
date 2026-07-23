import Foundation
import CoreAudio

func getDevices() {
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
    
    for id in deviceIDs {
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, &name)
        
        let inChannels = getChannelCount(id, scope: kAudioObjectPropertyScopeInput)
        let outChannels = getChannelCount(id, scope: kAudioObjectPropertyScopeOutput)
        
        print("Device: \(name) - In: \(inChannels) Out: \(outChannels)")
    }
}

func getChannelCount(_ id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
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

getDevices()
