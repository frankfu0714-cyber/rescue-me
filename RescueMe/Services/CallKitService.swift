// MARK: - Delivery Mechanism Note
// PRIMARY: CallKit CXProvider.reportNewIncomingCall
//   • When phone is LOCKED → system shows native full-screen incoming call UI (most authentic).
//   • When phone is UNLOCKED → system shows compact banner; our FakeIncomingCallView shows full-screen.
//   • Requires UIBackgroundModes: voip in Info.plist (already set).
//   • No special entitlements needed for local fake calls (PushKit/VoIP push is NOT used).
//
// FALLBACK: Local notification (see NotificationService.swift)
//   • Fires if app was suspended before the timer expired.
//   • Tapping it opens the app and shows FakeIncomingCallView.

import CallKit
import AVFoundation

final class CallKitService: NSObject {
    static let shared = CallKitService()

    var onAnswer: (() -> Void)?
    var onDecline: (() -> Void)?

    private var provider: CXProvider
    private var activeCallUUID: UUID?

    private override init() {
        let config = CXProviderConfiguration()
        config.supportsVideo = false
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic, .phoneNumber]
        config.maximumCallGroups = 1
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: .main)
    }

    func reportIncomingCall(from name: String) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: name)
        update.localizedCallerName = name
        update.hasVideo = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsHolding = false
        update.supportsDTMF = false

        let uuid = UUID()
        activeCallUUID = uuid

        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error {
                print("[CallKit] reportNewIncomingCall failed: \(error.localizedDescription)")
                // CallKit failed — our custom FakeIncomingCallView is already showing,
                // so the user experience is unaffected.
            }
        }
    }

    func endActiveCall() {
        guard let uuid = activeCallUUID else { return }
        provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
        activeCallUUID = nil
    }
}

// MARK: - CXProviderDelegate

extension CallKitService: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        activeCallUUID = nil
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        action.fulfill()
        onAnswer?()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
        onDecline?()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // CallKit activated the audio session — hand it to AudioService
        AudioService.shared.callKitActivated()
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        AudioService.shared.callKitDeactivated()
    }
}
