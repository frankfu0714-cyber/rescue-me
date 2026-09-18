import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            TabView {
                ContactsGridView()
                    .tabItem { Label("Rescue", systemImage: "phone.fill") }

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
            .tint(Theme.accent)

            // Full-screen call overlays — sit above the tab bar
            Group {
                if appState.callPhase == .ringing, let contact = appState.currentContact {
                    FakeIncomingCallView(contact: contact, audioMode: appState.currentAudioMode)
                        .zIndex(10)
                        .transition(.opacity)
                } else if appState.callPhase == .inCall, let contact = appState.currentContact {
                    FakeInCallView(contact: contact, audioMode: appState.currentAudioMode)
                        .zIndex(10)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: appState.callPhase)
        }
    }
}
