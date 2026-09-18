import SwiftUI
import Observation

@Observable
final class AppState {
    static let shared = AppState()

    // MARK: - State

    var contacts: [Contact] = []
    var callPhase: CallPhase = .idle
    var currentContact: Contact?
    var currentAudioMode: AudioMode = .silence
    var countdownRemaining: TimeInterval = 0

    // Settings (backed by UserDefaults directly)
    var defaultAudioMode: AudioMode {
        get { AudioMode(rawValue: UserDefaults.standard.string(forKey: "defaultAudioMode") ?? "") ?? .silence }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "defaultAudioMode") }
    }
    var vibrationEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "vibrationEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "vibrationEnabled") }
    }

    // MARK: - Types

    enum CallPhase: Equatable {
        case idle, countdown, ringing, inCall
    }

    // MARK: - Private

    private var countdownTimer: Timer?
    private var missedCallTimer: Timer?
    private let storageKey = "rescueme.contacts.v4"

    private init() {
        loadContacts()
        CallKitService.shared.onAnswer = { [weak self] in self?.answerCall() }
        CallKitService.shared.onDecline = { [weak self] in self?.endCall() }
    }

    // MARK: - Contacts

    func loadContacts() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([Contact].self, from: data) {
            contacts = saved
        } else {
            contacts = Contact.defaults
        }
    }

    func saveContacts() {
        guard let data = try? JSONEncoder().encode(contacts) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func addContact(_ contact: Contact) {
        contacts.append(contact)
        saveContacts()
    }

    func updateContact(_ contact: Contact) {
        guard let index = contacts.firstIndex(where: { $0.id == contact.id }) else { return }
        contacts[index] = contact
        saveContacts()
    }

    func deleteContacts(at offsets: IndexSet) {
        for index in offsets {
            if let filename = contacts[index].photoFileName {
                Contact.deletePhoto(filename: filename)
            }
        }
        contacts.remove(atOffsets: offsets)
        saveContacts()
    }

    // MARK: - Call Scheduling

    func scheduleCall(contact: Contact, delay: TimeInterval, audioMode: AudioMode) {
        cancelScheduled()
        currentContact = contact
        currentAudioMode = audioMode
        countdownRemaining = delay
        callPhase = .countdown

        // Foreground countdown
        var remaining = delay
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { return }
            remaining -= 1
            self.countdownRemaining = remaining
            if remaining <= 0 {
                timer.invalidate()
                self.countdownTimer = nil
                self.triggerCall()
            }
        }

        // Background safety net via local notification
        NotificationService.shared.schedule(contact: contact, audioMode: audioMode, delay: delay)
    }

    func cancelScheduled() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        NotificationService.shared.cancelAll()
        if callPhase == .countdown {
            callPhase = .idle
        }
        currentContact = nil
        countdownRemaining = 0
    }

    func triggerCall() {
        guard let contact = currentContact else { return }

        // PRIMARY: report to CallKit so lock-screen shows system call UI.
        // Note: CallKit fires CXEndCallAction internally after ~30 s on device /
        // much sooner in the Simulator. We do NOT wire that action to endCall()
        // — instead our missedCallTimer (45 s) is the sole auto-dismiss path.
        CallKitService.shared.reportIncomingCall(from: contact.name)

        // Show our custom UI (for foreground / unlocked case)
        callPhase = .ringing
        AudioService.shared.playRingtone()
        if vibrationEnabled { HapticsService.shared.startCallVibration() }

        // Missed-call fallback: auto-dismiss after 45 s if user doesn't act
        missedCallTimer?.invalidate()
        missedCallTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: false) { [weak self] _ in
            self?.endCall()
        }
    }

    func triggerCallFromNotification(contactId: UUID, audioModeRaw: String) {
        guard let contact = contacts.first(where: { $0.id == contactId }) else { return }
        currentContact = contact
        currentAudioMode = AudioMode(rawValue: audioModeRaw) ?? contact.defaultAudioMode
        NotificationService.shared.cancelAll()
        triggerCall()
    }

    func answerCall() {
        missedCallTimer?.invalidate()
        missedCallTimer = nil
        AudioService.shared.stopRingtone()
        HapticsService.shared.stopCallVibration()
        AudioService.shared.startCallAudio(mode: currentAudioMode)
        callPhase = .inCall
    }

    func endCall() {
        missedCallTimer?.invalidate()
        missedCallTimer = nil
        CallKitService.shared.endActiveCall()
        AudioService.shared.stopAll()
        HapticsService.shared.stopCallVibration()
        callPhase = .idle
        currentContact = nil
    }
}
