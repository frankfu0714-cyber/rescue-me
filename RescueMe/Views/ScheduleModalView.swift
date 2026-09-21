import SwiftUI
import PhotosUI

struct ScheduleModalView: View {
    /// Original contact passed in — used only for the ID and initial audio mode.
    /// All rendering uses `liveContact` so it reflects any photo saved in this session.
    let contact: Contact
    @Binding var isPresented: Bool
    @Environment(AppState.self) private var appState

    @State private var selectedPreset: Preset = .thirtySeconds
    @State private var customMinutes: Int = 5
    @State private var audioMode: AudioMode
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var showAvatarPicker = false

    /// Always the freshest copy from appState so the avatar updates the moment
    /// a photo is saved (without needing to dismiss and reopen the sheet).
    private var liveContact: Contact {
        appState.contacts.first(where: { $0.id == contact.id }) ?? contact
    }

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
                            contact: liveContact,
                            delay: effectiveDelay,
                            audioMode: audioMode
                        )
                        isPresented = false
                    }
                    .fontWeight(.bold)
                    .tint(Theme.accent)
                }
            }
            // Photo picked from the avatar picker sheet
            .task(id: avatarPickerItem) {
                guard let item = avatarPickerItem else { return }
                avatarPickerItem = nil
                guard
                    let data = try? await item.loadTransferable(type: Data.self),
                    let img = UIImage(data: data)
                else { return }
                var updated = appState.contacts.first(where: { $0.id == contact.id }) ?? contact
                if let old = updated.photoFileName { Contact.deletePhoto(filename: old) }
                updated.photoFileName = Contact.savePhoto(img)
                updated.defaultAssetName = liveContact.defaultAssetName  // preserve current preset
                appState.updateContact(updated)
                showAvatarPicker = false
            }
            .sheet(isPresented: $showAvatarPicker) {
                avatarPickerSheet
                    .presentationDetents(
                        Contact.assetVariants(for: liveContact.defaultAssetName).isEmpty
                            ? [.height(160)] : [.height(260)]
                    )
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Sections

    private var callerSection: some View {
        Section {
            HStack(spacing: 14) {
                Button { showAvatarPicker = true } label: {
                    ContactAvatarView(contact: liveContact, size: 52)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white, Theme.accent)
                                .offset(x: 3, y: 3)
                        }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(liveContact.name)
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

    // MARK: - Avatar picker sheet (immediate-save variant)

    private var avatarPickerSheet: some View {
        AvatarVariantPicker(
            variants: Contact.assetVariants(for: liveContact.defaultAssetName),
            selectedAssetName: liveContact.defaultAssetName,
            hasCustomPhoto: liveContact.photoFileName != nil,
            onSelectVariant: { assetName in
                var updated = appState.contacts.first(where: { $0.id == contact.id }) ?? contact
                if let old = updated.photoFileName { Contact.deletePhoto(filename: old) }
                updated.photoFileName = nil
                updated.defaultAssetName = assetName
                appState.updateContact(updated)
                showAvatarPicker = false
            },
            onRemoveCustomPhoto: {
                var updated = appState.contacts.first(where: { $0.id == contact.id }) ?? contact
                if let old = updated.photoFileName { Contact.deletePhoto(filename: old) }
                updated.photoFileName = nil
                appState.updateContact(updated)
                showAvatarPicker = false
            },
            photoPickerItem: $avatarPickerItem
        )
    }
}

// MARK: - Reusable Avatar Variant Picker

struct AvatarVariantPicker: View {
    let variants: [String]
    let selectedAssetName: String?
    let hasCustomPhoto: Bool
    let onSelectVariant: (String) -> Void
    let onRemoveCustomPhoto: () -> Void
    @Binding var photoPickerItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !variants.isEmpty {
                Text("Pick a look")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(variants, id: \.self) { assetName in
                            variantThumb(assetName)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
            }

            Divider().padding(.leading, 20)

            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                Label("Choose Custom Photo", systemImage: "photo.on.rectangle.angled")
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .frame(height: 52)
            }
            .buttonStyle(.plain)

            if hasCustomPhoto {
                Divider().padding(.leading, 20)

                Button(role: .destructive, action: onRemoveCustomPhoto) {
                    Label("Remove Custom Photo", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .frame(height: 52)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func variantThumb(_ assetName: String) -> some View {
        let isSelected = !hasCustomPhoto && selectedAssetName == assetName
        Button { onSelectVariant(assetName) } label: {
            Group {
                if let img = UIImage(named: assetName) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Circle().fill(Color(.systemGray4))
                }
            }
            .frame(width: 60, height: 60)
            .overlay(Circle().strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3))
            .shadow(color: .black.opacity(0.1), radius: isSelected ? 5 : 2, y: 1)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
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
                // Tier 1: user-set photo
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else if let assetName = contact.defaultAssetName,
                      let assetImage = UIImage(named: assetName) {
                // Tier 2: bundled default asset (seeded contacts)
                Image(uiImage: assetImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                // Tier 3: color circle + emoji or initials
                ZStack {
                    Circle().fill(Color(hex: contact.colorHex))
                    if let emoji = contact.emoji {
                        Text(emoji)
                            .font(.system(size: size * 0.55))
                    } else {
                        Text(contact.initials)
                            .font(.system(size: size * 0.38, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .task(id: contact.photoFileName) {
            photo = contact.loadPhoto()
        }
    }
}
