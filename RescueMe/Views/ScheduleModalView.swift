import SwiftUI

struct ScheduleModalView: View {
    let contact: Contact
    @Binding var isPresented: Bool
    @Environment(AppState.self) private var appState

    @State private var selectedPreset: Preset = .thirtySeconds
    @State private var customMinutes: Int = 5
    @State private var audioMode: AudioMode

    init(contact: Contact, isPresented: Binding<Bool>) {
        self.contact = contact
        self._isPresented = isPresented
        self._audioMode = State(initialValue: contact.defaultAudioMode)
    }

    enum Preset: String, CaseIterable, Identifiable {
        case fiveSeconds  = "5s"
        case thirtySeconds = "30s"
        case oneMinute    = "1 min"
        case threeMinutes = "3 min"
        case fiveMinutes  = "5 min"
        case custom       = "Custom"

        var id: String { rawValue }

        var seconds: TimeInterval? {
            switch self {
            case .fiveSeconds:   return 5
            case .thirtySeconds: return 30
            case .oneMinute:     return 60
            case .threeMinutes:  return 180
            case .fiveMinutes:   return 300
            case .custom:        return nil
            }
        }
    }

    private var effectiveDelay: TimeInterval {
        selectedPreset.seconds ?? TimeInterval(customMinutes * 60)
    }

    var body: some View {
        NavigationStack {
            Form {
                callerSection
                delaySection
                audioSection
            }
            .navigationTitle("Schedule Call")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Rescue Me!") {
                        appState.scheduleCall(
                            contact: contact,
                            delay: effectiveDelay,
                            audioMode: audioMode
                        )
                        isPresented = false
                    }
                    .fontWeight(.bold)
                    .tint(Theme.accent)
                }
            }
        }
    }

    // MARK: - Sections

    private var callerSection: some View {
        Section {
            HStack(spacing: 14) {
                ContactAvatarView(contact: contact, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.system(size: 17, weight: .semibold))
                    Text("will call in…")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var delaySection: some View {
        Section("Call delay") {
            Picker("Delay", selection: $selectedPreset) {
                ForEach(Preset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

            if selectedPreset == .custom {
                Picker("Minutes", selection: $customMinutes) {
                    ForEach(1...60, id: \.self) { m in
                        Text(m == 1 ? "1 minute" : "\(m) minutes").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
            }
        }
    }

    private var audioSection: some View {
        Section("Audio during call") {
            Picker("Audio", selection: $audioMode) {
                ForEach(AudioMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

            HStack {
                Spacer()
                Text(audioMode.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

// MARK: - Reusable Avatar View

struct ContactAvatarView: View {
    let contact: Contact
    let size: CGFloat
    @State private var photo: UIImage?

    var body: some View {
        Group {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle().fill(Color(hex: contact.colorHex))
                    Text(contact.initials)
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .task(id: contact.photoFileName) {
            photo = contact.loadPhoto()
        }
    }
}
