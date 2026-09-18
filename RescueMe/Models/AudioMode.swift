import Foundation

enum AudioMode: String, Codable, CaseIterable, Identifiable {
    case silence = "Silence"
    case mumble = "Mumble"
    case ambient = "Ambient"
    case realisticMom = "Realistic"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .silence: return "No audio"
        case .mumble: return "Distant voice murmur"
        case .ambient: return "Background noise"
        case .realisticMom: return "Mom's voice with ambient"
        }
    }

    var icon: String {
        switch self {
        case .silence: return "speaker.slash.fill"
        case .mumble: return "waveform.and.person.filled"
        case .ambient: return "waveform"
        case .realisticMom: return "person.wave.2.fill"
        }
    }
}
