import Foundation

enum AudioMode: String, Codable, CaseIterable, Identifiable {
    case silence  = "Silence"
    case mumble   = "Mumble"
    case ambient  = "Ambient"
    case realistic = "Realistic"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .silence:   return "No audio"
        case .mumble:    return "Distant voice murmur"
        case .ambient:   return "Background noise"
        case .realistic: return "Caller's voice with ambient"
        }
    }

    var icon: String {
        switch self {
        case .silence:   return "speaker.slash.fill"
        case .mumble:    return "waveform.and.person.filled"
        case .ambient:   return "waveform"
        case .realistic: return "person.wave.2.fill"
        }
    }
}

enum VoiceLanguage: String, Codable, CaseIterable, Identifiable {
    case english = "English"
    case chinese = "中文"

    var id: String { rawValue }

    /// Subfolder name inside each voice pack (e.g. VoicePacks/Mom/en/).
    var folderName: String {
        switch self {
        case .english: return "en"
        case .chinese: return "zh"
        }
    }
}
