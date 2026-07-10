import Foundation

struct Track: Identifiable, Equatable {
    let id: UUID
    let name: String
    let originalURL: URL
    var vocalsURL: URL?
    var instrumentalURL: URL?
    var lyrics: String?
    
    var isProcessing: Bool = false
    var progressStatus: String = ""
    
    var isSeparated: Bool {
        return instrumentalURL != nil
    }
    
    init(id: UUID = UUID(), name: String, originalURL: URL, vocalsURL: URL? = nil, instrumentalURL: URL? = nil, lyrics: String? = nil) {
        self.id = id
        self.name = name
        self.originalURL = originalURL
        self.vocalsURL = vocalsURL
        self.instrumentalURL = instrumentalURL
        self.lyrics = lyrics
    }
}
