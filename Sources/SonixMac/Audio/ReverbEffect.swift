import AVFoundation

struct ReverbEffect: Identifiable {
    let id: Int
    let name: String
    let emoji: String
    let preset: AVAudioUnitReverbPreset

    static let all: [ReverbEffect] = [
        ReverbEffect(id: 0,  name: "Small Room",     emoji: "🏠", preset: .smallRoom),
        ReverbEffect(id: 1,  name: "Bathroom",       emoji: "🚿", preset: .mediumChamber),
        ReverbEffect(id: 2,  name: "Medium Room",    emoji: "🏡", preset: .mediumRoom),
        ReverbEffect(id: 3,  name: "Large Room",     emoji: "🏛️", preset: .largeRoom),
        ReverbEffect(id: 4,  name: "Medium Hall",    emoji: "🎭", preset: .mediumHall),
        ReverbEffect(id: 5,  name: "Large Hall",     emoji: "🎪", preset: .largeHall),
        ReverbEffect(id: 6,  name: "Cathedral",      emoji: "⛪", preset: .cathedral),
        ReverbEffect(id: 7,  name: "Plate",          emoji: "🎙️", preset: .plate),
    ]
}
