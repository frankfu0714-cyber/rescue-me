// MARK: - Design Note
// Styled after the iOS in-call screen:
//   duration top-center · caller name · avatar · 6-button grid · red End button.
// All grid buttons are visually accurate but non-functional except End Call.

import SwiftUI

struct FakeInCallView: View {
    let contact: Contact
    let audioMode: AudioMode
    @Environment(AppState.self) private var appState

    @State private var callStart = Date()
    @State private var elapsed: TimeInterval = 0
    @State private var isMuted = false
    @State private var isSpeaker = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Theme.inCallBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                // Duration
                Text(durationString)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(white: 0.65))

                // Caller name
                Text(contact.name)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                // Subtitle
                Text("iPhone")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(white: 0.5))
                    .padding(.top, 4)

                // Avatar
                ContactAvatarView(contact: contact, size: 88)
                    .padding(.top, 20)

                Spacer()

                // 2×3 action button grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                    inCallButton(icon: isMuted ? "mic.slash.fill" : "mic.fill",
                                 label: isMuted ? "Unmute" : "Mute",
                                 active: isMuted) { isMuted.toggle() }

                    inCallButton(icon: "circle.grid.3x3.fill", label: "Keypad") {}

                    inCallButton(icon: isSpeaker ? "speaker.wave.3.fill" : "speaker.fill",
                                 label: "Speaker",
                                 active: isSpeaker) { isSpeaker.toggle() }

                    inCallButton(icon: "plus",             label: "add call") {}
                    inCallButton(icon: "video.fill",       label: "FaceTime") {}
                    inCallButton(icon: "person.crop.circle.fill", label: "Contacts") {}
                }
                .padding(.horizontal, 36)

                // End call
                Button {
                    withAnimation { appState.endCall() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Theme.callRed)
                            .frame(width: 80, height: 80)
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(CallButtonStyle())
                .padding(.top, 32)
                .padding(.bottom, 52)
            }
        }
        .statusBarHidden(true)
        .onReceive(ticker) { _ in
            elapsed = Date().timeIntervalSince(callStart)
        }
    }

    private var durationString: String {
        let m = Int(elapsed) / 60
        let s = Int(elapsed) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func inCallButton(
        icon: String,
        label: String,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(active ? Color.white : Theme.inCallButtonBg)
                        .frame(width: 66, height: 66)
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundStyle(active ? Color.black : Color.white)
                }
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.75))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared button scale style

private struct CallButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
