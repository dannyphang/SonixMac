import Foundation
import AVFoundation

func testEngine() {
    let audioEngine = AVAudioEngine()
    
    // We'll just use the default input and output devices for the test
    let inputNode = audioEngine.inputNode
    let mainMixer = audioEngine.mainMixerNode
    let format = inputNode.inputFormat(forBus: 0)
    
    print("Input format: \(format)")
    
    audioEngine.connect(inputNode, to: mainMixer, format: format)
    
    do {
        audioEngine.prepare()
        try audioEngine.start()
        print("Engine started successfully!")
    } catch {
        print("Engine failed to start: \(error)")
    }
}

testEngine()
