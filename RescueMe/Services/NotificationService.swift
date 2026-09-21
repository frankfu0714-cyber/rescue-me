import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private let categoryId = "RESCUE_CALL"
    private let pendingId = "rescue-me-pending-call"

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func schedule(contact: Contact, audioMode: AudioMode, voiceLanguage: VoiceLanguage, delay: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = contact.name
        content.body = "Incoming call"
        content.sound = .default
        content.userInfo = [
            "contactId": contact.id.uuidString,
            "audioMode": audioMode.rawValue,
            "voiceLanguage": voiceLanguage.rawValue,
            "action": "fakeCall",
        ]
        content.categoryIdentifier = categoryId

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(identifier: pendingId, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("[Notification] Schedule error: \(error.localizedDescription)") }
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [pendingId])
    }
}
