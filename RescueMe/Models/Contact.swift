import Foundation
import UIKit

struct Contact: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    var defaultAudioMode: AudioMode = .silence
    var photoFileName: String?
    /// Preset emoji rendered large over the color circle — seeded contacts only.
    var emoji: String?
    /// Name of an xcassets image set used as the default avatar — seeded contacts only.
    var defaultAssetName: String?
    /// Folder name inside VoicePacks/ for "Realistic" mode (e.g. "Mom", "DrChen").
    /// Nil for user-added contacts (Realistic plays nothing).
    var voicePack: String?

    var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
        let result = letters.joined().uppercased()
        return result.isEmpty ? String(name.prefix(1)).uppercased() : result
    }

    /// Returns all ethnic variant asset names for the given asset name suffix.
    static func assetVariants(for assetName: String?) -> [String] {
        guard let assetName else { return [] }
        let ethnicities = ["asian", "black", "latino", "white"]
        for e in ethnicities where assetName.hasSuffix("-\(e)") {
            let base = String(assetName.dropLast(e.count + 1))
            return ethnicities.map { "\(base)-\($0)" }
        }
        return []
    }

    func loadPhoto() -> UIImage? {
        guard let filename = photoFileName else { return nil }
        let url = Contact.photoDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static var photoDirectory: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ContactPhotos", isDirectory: true)
    }

    static func savePhoto(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
        let filename = UUID().uuidString + ".jpg"
        try? FileManager.default.createDirectory(at: photoDirectory, withIntermediateDirectories: true)
        try? data.write(to: photoDirectory.appendingPathComponent(filename))
        return filename
    }

    static func deletePhoto(filename: String) {
        let url = photoDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    static let presetColors: [String] = [
        "#FF6B9D", "#4A90E2", "#7B68EE", "#26A69A",
        "#EF5350", "#78909C", "#FF8A65", "#66BB6A",
        "#FFA726", "#AB47BC",
    ]

    static let defaults: [Contact] = [
        Contact(name: "Mom",               colorHex: "#FF6B9D", emoji: "👩",    defaultAssetName: "avatar-mom-asian",       voicePack: "Mom"),
        Contact(name: "Dad",               colorHex: "#4A90E2", emoji: "👨",    defaultAssetName: "avatar-dad-black",       voicePack: "Dad"),
        Contact(name: "Boss",              colorHex: "#5C5C8A", emoji: "👨‍💼",  defaultAssetName: "avatar-boss-white",      voicePack: "Boss"),
        Contact(name: "Dr. Chen",          colorHex: "#26A69A", emoji: "👨‍⚕️", defaultAssetName: "avatar-dr-chen-asian",   voicePack: "DrChen"),
        Contact(name: "Emergency Contact", colorHex: "#EF5350", emoji: "🚨",   defaultAssetName: "avatar-emergency-latino", voicePack: "Emergency"),
        Contact(name: "Unknown Number",    colorHex: "#78909C", emoji: "❓",    defaultAssetName: "avatar-unknown-shared",  voicePack: "Unknown"),
    ]
}
