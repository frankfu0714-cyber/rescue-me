import SwiftUI
import UserNotifications

@main
struct RescueMeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(AppState.shared)
        }
    }
}

// MARK: - App Delegate (notification handling)

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.requestPermission()
        return true
    }

    // Notification received while app is foregrounded — suppress system banner, trigger call directly
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handleNotification(notification.request.content.userInfo)
        completionHandler([])   // no banner — we show FakeIncomingCallView ourselves
    }

    // User tapped notification (app was backgrounded/suspended)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotification(response.notification.request.content.userInfo)
        completionHandler()
    }

    private func handleNotification(_ userInfo: [AnyHashable: Any]) {
        guard
            userInfo["action"] as? String == "fakeCall",
            let idString = userInfo["contactId"] as? String,
            let contactId = UUID(uuidString: idString)
        else { return }

        let audioModeRaw = userInfo["audioMode"] as? String ?? AudioMode.silence.rawValue
        let voiceLanguageRaw = userInfo["voiceLanguage"] as? String ?? VoiceLanguage.english.rawValue

        DispatchQueue.main.async {
            // Guard against double-trigger (timer may have already fired if app stayed in foreground)
            guard AppState.shared.callPhase == .idle else { return }
            AppState.shared.triggerCallFromNotification(
                contactId: contactId,
                audioModeRaw: audioModeRaw,
                voiceLanguageRaw: voiceLanguageRaw
            )
        }
    }
}
