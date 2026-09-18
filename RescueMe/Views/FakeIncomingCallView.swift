// MARK: - Design Note
// Styled as close as possible to the real iOS incoming call screen.
// • Black/gradient background, white caller name, "iPhone" subtitle.
// • Round Decline (red) + Accept (green) buttons at bottom.
// • Swipe-up gesture on Accept to mimic lock-screen "slide to answer".
// App Store risk: guideline 4.1/4.3 (deceptive UI) — acknowledged by Frank.

import SwiftUI

struct FakeIncomingCallView: View {
    let contact: Contact
    let audioMode: AudioMode
    @Environment(AppState.self) private var appState

    // Slide-to-answer state
    @State private var slideOffset: CGFloat = 0
    private let slideThreshold: CGFloat = 60

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                statusBar
                    .padding(.top, 12)
                    .padding(.horizontal, 24)

                Spacer()

                callerInfo
                    .padding(.bottom, 12)

                Spacer()

                bottomControls
                    .padding(.bottom, 52)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }

    // MARK: - Sub-views

    private var background: some View {
        ZStack {
            Color.black
            LinearGradient(
                colors: [Color(white: 0.14), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var statusBar: some View {
        HStack {
            Text(Date(), style: .time)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "wifi")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Image(systemName: "battery.100percent")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    private var callerInfo: some View {
        VStack(spacing: 14) {
            // Caller avatar
            ContactAvatarView(contact: contact, size: 120)
                .shadow(color: .black.opacity(0.4), radius: 16, y: 4)

            // Name
            Text(contact.name)
                .font(.system(size: 38, weight: .light, design: .default))
                .foregroundStyle(.white)
                .padding(.top, 6)

            // Subtitle — iOS shows carrier name; we show "iPhone"
            Text("iPhone")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Color(white: 0.72))

            Text("Incoming Call")
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.55))
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 28) {
            HStack(spacing: 80) {
                // Decline
                callActionButton(
                    icon: "phone.down.fill",
                    label: "Decline",
                    color: Theme.callRed
                ) {
                    withAnimation { appState.endCall() }
                }

                // Accept (with slide-up hint on long press)
                callActionButton(
                    icon: "phone.fill",
                    label: "Accept",
                    color: Theme.callGreen
                ) {
                    withAnimation { appState.answerCall() }
                }
            }
        }
    }

    private func callActionButton(
        icon: String,
        label: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 10) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 82, height: 82)
                    Image(systemName: icon)
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(CallButtonStyle())

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(white: 0.85))
        }
    }
}

// MARK: - Button Style (scale feedback)

private struct CallButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
