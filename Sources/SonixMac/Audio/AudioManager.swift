import Foundation
import AVFoundation
import Combine

@MainActor
class AudioManager: ObservableObject {
    @Published var player: AVPlayer?
    
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isLooping = false
    @Published var hasVideo = false
    @Published var isDraggingSlider = false
    
    @Published var playbackMode: PlaybackMode = .original {
        didSet {
            updateVolumes()
        }
    }
    
    @Published var masterVolume: Float = 1.0 {
        didSet {
            player?.volume = masterVolume
        }
    }
    @Published var vocalsVolume: Float = 1.0 {
        didSet {
            updateVolumes()
        }
    }
    
    @Published var instrumentalVolume: Float = 1.0 {
        didSet {
            updateVolumes()
        }
    }
    
    enum PlaybackMode {
        case original
        case karaoke
    }
    
    private var isVocalsOriginal: Bool = false
    private var vocalsTrackID: CMPersistentTrackID?
    private var instrumentalTrackID: CMPersistentTrackID?
    
    private var timeObserver: Any?
    
    private func updateVolumes() {
        guard let playerItem = player?.currentItem else { return }
        
        var mixParameters: [AVMutableAudioMixInputParameters] = []
        
        if let vId = vocalsTrackID {
            let vParams = AVMutableAudioMixInputParameters()
            vParams.trackID = vId
            if playbackMode == .karaoke {
                vParams.setVolume(0.0, at: .zero)
            } else {
                vParams.setVolume(1.0 * vocalsVolume, at: .zero)
            }
            mixParameters.append(vParams)
        }
        
        if let iId = instrumentalTrackID {
            let iParams = AVMutableAudioMixInputParameters()
            iParams.trackID = iId
            if playbackMode == .karaoke {
                iParams.setVolume(1.0 * instrumentalVolume, at: .zero)
            } else {
                iParams.setVolume((isVocalsOriginal ? 0.0 : 1.0) * instrumentalVolume, at: .zero)
            }
            mixParameters.append(iParams)
        }
        
        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = mixParameters
        playerItem.audioMix = audioMix
    }
    
    func setupAndPlay(originalURL: URL, vocalsURL: URL, instrumentalURL: URL, isVocalsOriginal: Bool = false) {
        stop()
        self.isVocalsOriginal = isVocalsOriginal
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let composition = AVMutableComposition()
                
                // Assets
                let origAsset = AVURLAsset(url: originalURL)
                let instAsset = AVURLAsset(url: instrumentalURL)
                let vocAsset = AVURLAsset(url: vocalsURL)
                
                // Load tracks (async in newer iOS/macOS, but we can try awaiting them or just use older API for local files)
                // Since this is macOS 13+, we should use loadTracks
                let origVideoTracks = try await origAsset.loadTracks(withMediaType: .video)
                let instAudioTracks = try await instAsset.loadTracks(withMediaType: .audio)
                let vocAudioTracks = try await vocAsset.loadTracks(withMediaType: .audio)
                
                let timeRange = try await CMTimeRange(start: .zero, duration: instAsset.load(.duration))
                
                // 1. Add Video Track
                var foundVideo = false
                if let firstVideoTrack = origVideoTracks.first {
                    if let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                        try compVideoTrack.insertTimeRange(timeRange, of: firstVideoTrack, at: .zero)
                        foundVideo = true
                    }
                }
                
                // 2. Add Instrumental Audio Track
                if let firstInstTrack = instAudioTracks.first {
                    if let compInstTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                        try compInstTrack.insertTimeRange(timeRange, of: firstInstTrack, at: .zero)
                        self.instrumentalTrackID = compInstTrack.trackID
                    }
                }
                
                // 3. Add Vocals Audio Track
                if let firstVocTrack = vocAudioTracks.first {
                    if let compVocTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                        try compVocTrack.insertTimeRange(timeRange, of: firstVocTrack, at: .zero)
                        self.vocalsTrackID = compVocTrack.trackID
                    }
                }
                
                let playerItem = AVPlayerItem(asset: composition)
                self.player = AVPlayer(playerItem: playerItem)
                self.player?.volume = self.masterVolume
                
                if !AudioDeviceManager.shared.selectedOutputDeviceUID.isEmpty {
                    self.player?.audioOutputDeviceUniqueID = AudioDeviceManager.shared.selectedOutputDeviceUID
                }
                
                self.hasVideo = foundVideo
                
                self.duration = timeRange.duration.seconds
                
                self.updateVolumes()
                
                self.setupTimeObserver()
                
                NotificationCenter.default.addObserver(forName: .audioDeviceChanged, object: nil, queue: .main) { [weak self] _ in
                    Task { @MainActor in
                        if let uid = AudioDeviceManager.shared.selectedOutputDeviceUID as String?, !uid.isEmpty {
                            self?.player?.audioOutputDeviceUniqueID = uid
                        }
                    }
                }
                
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
                    Task { @MainActor in
                        self?.handleItemDidPlayToEndTime()
                    }
                }
                
                self.player?.play()
                self.isPlaying = true
                
            } catch {
                print("Failed to setup AVPlayer: \(error)")
            }
        }
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self, !self.isDraggingSlider else { return }
                self.currentTime = time.seconds
            }
        }
    }
    
    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time)
    }
    
    func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }
    
    func stop() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        NotificationCenter.default.removeObserver(self, name: .audioDeviceChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
        player?.pause()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }
    
    private func handleItemDidPlayToEndTime() {
        if isLooping {
            seek(to: 0)
            player?.play()
        } else {
            isPlaying = false
        }
    }
}
