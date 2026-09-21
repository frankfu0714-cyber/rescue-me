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
    var currentVoiceLanguage: VoiceLanguage = .english
    var countdownRemaining: TimeInterval = 0

    // Settings — stored and observed so @Bindable works; persisted to UserDefaults via didSet
    var defaultAudioMode: AudioMode = .silence {
        didSet { UserDefaults.standard.set(defaultAudioMode.rawValue, forKey: "defaultAudioMode") }
    }
    var vibrationEnabled: Bool = true {
        didSet { UserDefaults.standard.set(vibrationEnabled, forKey: "vibrationEnabled") }
    }
    var voiceLanguage: VoiceLanguage = .english {
        didSet { UserDefaults.standard.set(voiceLanguage.rawValue, forKey: "voiceLanguage") }
    }

    // MARK: - Types

    enum CallPhase: Equatable {
        case idle, countdown, ringing, inCall
    }

    // MARK: - Private

    private var countdownTimer: Timer?
    private var missedCallTimer: Timer?
    private let storageKey = "rescueme.contacts.v5"

    private init() {
        // Load persisted settings before anything else
        if let raw = UserDefaults.standard.string(forKey: "defaultAudioMode"),
           let mode = AudioMode(rawValue: raw) { defaultAudioMode = mode }
        if let b = UserDefaults.standard.object(forKey: "vibrationEnabled") as? Bool { vibrationEnabled = b }
        if let raw = UserDefaults.standard.string(forKey: "voiceLanguage"),
           let lang = VoiceLanguage(rawValue: raw) { voiceLanguage = lang }

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

    func scheduleCall(contact: Contact, delay: TimeInterval, audioMode: AudioMode, voiceLanguage: VoiceLanguage? = nil) {
        cancelScheduled()
        currentContact = contact
        currentAudioMode = audioMode
        currentVoiceLanguage = voiceLanguage ?? self.voiceLanguage
        countdownRemaining = delay
        callPhase = .countdown

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

        NotificationService.shared.schedule(
            contact: contact,
            audioMode: audioMode,
            voiceLanguage: currentVoiceLanguage,
            delay: delay
        )
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
        CallKitService.shared.reportIncomingCall(from: contact.name)
        callPhase = .ringing
        AudioService.shared.playRingtone()
        if vibrationEnabled { HapticsService.shared.startCallVibration() }

        missedCallTimer?.invalidate()
        missedCallTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: false) { [weak self] _ in
            self?.endCall()
        }
    }

    func triggerCallFromNotification(contactId: UUID, audioModeRaw: String, voiceLanguageRaw: String) {
        guard let contact = contacts.first(where: { $0.id == contactId }) else { return }
        // Cancel countdown timer so it can't double-fire if it was still running
        countdownTimer?.invalidate()
        countdownTimer = nil
        currentContact = contact
        currentAudioMode = AudioMode(rawValue: audioModeRaw) ?? contact.defaultAudioMode
        currentVoiceLanguage = VoiceLanguage(rawValue: voiceLanguageRaw) ?? voiceLanguage
        NotificationService.shared.cancelAll()
        triggerCall()
    }

    func answerCall() {
        missedCallTimer?.invalidate()
        missedCallTimer = nil
        AudioService.shared.stopRingtone()
        HapticsService.shared.stopCallVibration()
        AudioService.shared.startCallAudio(
            mode: currentAudioMode,
            contact: currentContact,
            language: currentVoiceLanguage
        )
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
