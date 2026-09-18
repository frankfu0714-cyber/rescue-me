import UIKit
import AudioToolbox

final class HapticsService {
    static let shared = HapticsService()
    private var vibrationTimer: Timer?
    private init() {}

    func startCallVibration() {
        stopCallVibration()
        fireVibrationBurst()
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.fireVibrationBurst()
        }
    }

    func stopCallVibration() {
        vibrationTimer?.invalidate()
        vibrationTimer = nil
    }

    private func fireVibrationBurst() {
        // Three quick buzzes separated by 150 ms — mirrors iOS incoming-call haptic
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
    }
}
