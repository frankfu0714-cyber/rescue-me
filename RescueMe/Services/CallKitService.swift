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
    private let callController = CXCallController()
    private var activeCallUUID: UUID?

    // True while a CXAnswerCallAction is in-flight from our in-app button,
    // so the delegate knows not to re-trigger onAnswer and loop.
    private var answeringFromApp = false

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
        answeringFromApp = false   // reset for each new call

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
            }
        }
    }

    /// Called when the user answers via our in-app UI.
    /// Requests CXAnswerCallAction so CallKit dismisses its banner and stops OS vibration.
    func answerActiveCall() {
        guard let uuid = activeCallUUID, !answeringFromApp else { return }
        answeringFromApp = true
        callController.request(CXTransaction(action: CXAnswerCallAction(call: uuid))) { [weak self] error in
            if let error {
                print("[CallKit] Answer request failed: \(error.localizedDescription)")
                self?.answeringFromApp = false  // reset so the flag doesn't get stuck
            }
        }
    }

    /// Called when the call ends for any reason (user decline, end call, missed-call timer).
    /// Requests CXEndCallAction so CallKit dismisses its UI and stops OS vibration.
    func endActiveCall() {
        guard let uuid = activeCallUUID else { return }
        activeCallUUID = nil   // nil before the async request so re-entry is a no-op
        callController.request(CXTransaction(action: CXEndCallAction(call: uuid))) { [weak self] error in
            if let error {
                print("[CallKit] End request failed: \(error.localizedDescription)")
                // Fallback: report directly (handles already-ended call edge cases)
                self?.provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
            }
        }
    }
}

// MARK: - CXProviderDelegate

extension CallKitService: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        activeCallUUID = nil
        answeringFromApp = false
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        action.fulfill()
        if answeringFromApp {
            // In-app answer: our answerCall() already ran; just clear the flag.
            answeringFromApp = false
        } else {
            // Lock-screen answer: tell AppState to transition.
            onAnswer?()
        }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
        // Call onDecline for both lock-screen Decline and CallKit internal timeout.
        // AppState.endCall() guards against double-end (callPhase != .idle check).
        onDecline?()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        AudioService.shared.callKitActivated()
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        AudioService.shared.callKitDeactivated()
    }
}
