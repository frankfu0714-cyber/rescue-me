import SwiftUI
import PhotosUI

struct AddEditContactView: View {
    let contact: Contact?          // nil → adding new
    @Binding var isPresented: Bool
    @Environment(AppState.self) private var appState

    @State private var name: String
    @State private var selectedColor: String
    @State private var defaultAudioMode: AudioMode
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var existingPhotoFileName: String?
    @State private var selectedAssetName: String?

    init(contact: Contact?, isPresented: Binding<Bool>) {
        self.contact = contact
        self._isPresented = isPresented
        self._name = State(initialValue: contact?.name ?? "")
        self._selectedColor = State(initialValue: contact?.colorHex ?? Contact.presetColors[0])
        self._defaultAudioMode = State(initialValue: contact?.defaultAudioMode ?? .silence)
        self._existingPhotoFileName = State(initialValue: contact?.photoFileName)
        self._selectedAssetName = State(initialValue: contact?.defaultAssetName)
    }

    private var isEditing: Bool { contact != nil }

    var body: some View {
        NavigationStack {
            Form {
                avatarSection
                presetAvatarSection
                infoSection
                audioSection
            }
            .navigationTitle(isEditing ? "Edit Contact" : "New Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .task(id: selectedPhoto) {
                guard let item = selectedPhoto else { return }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    previewImage = img
                    // Custom photo overrides any preset selection
                    selectedAssetName = nil
                }
            }
        }
    }

    // MARK: - Sections

    private var avatarSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    // Avatar preview — mirrors the ContactAvatarView fallback chain
                    Group {
                        if let img = previewImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .clipShape(Circle())
                        } else if let fn = existingPhotoFileName,
                                  let img = Contact(name: name, colorHex: selectedColor, photoFileName: fn).loadPhoto() {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .clipShape(Circle())
                        } else if let assetName = selectedAssetName,
                                  let img = UIImage(named: assetName) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle().fill(Color(hex: selectedColor))
                                if let emoji = contact?.emoji {
                                    Text(emoji)
                                        .font(.system(size: 50))
                                } else {
                                    Text(initials)
                                        .font(.system(size: 36, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                    .frame(width: 90, height: 90)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        let hasPhoto = previewImage != nil || existingPhotoFileName != nil || selectedAssetName != nil
                        Text(hasPhoto ? "Change Photo" : "Add Photo")
                            .font(.system(size: 14))
                    }

                    if previewImage != nil || existingPhotoFileName != nil {
                        Button("Remove Photo", role: .destructive) {
                            previewImage = nil
                            existingPhotoFileName = nil
                            selectedPhoto = nil
                            // Restore preset asset (if contact originally had one)
                            selectedAssetName = contact?.defaultAssetName
                        }
                        .font(.system(size: 13))
                    }
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var presetAvatarSection: some View {
        let variants = Contact.assetVariants(for: contact?.defaultAssetName)
        if !variants.isEmpty {
            Section("Pick a look") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(variants, id: \.self) { assetName in
                            presetThumbnail(assetName: assetName)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
    }

    @ViewBuilder
    private func presetThumbnail(assetName: String) -> some View {
        let isSelected = selectedAssetName == assetName && previewImage == nil && existingPhotoFileName == nil
        Button {
            selectedAssetName = assetName
            // Auto-clear any custom photo so the preset shows immediately
            previewImage = nil
            existingPhotoFileName = nil
            selectedPhoto = nil
        } label: {
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
            .frame(width: 52, height: 52)
            .overlay(
                Circle()
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            .shadow(color: .black.opacity(isSelected ? 0.18 : 0.06), radius: isSelected ? 4 : 2, y: 1)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var infoSection: some View {
        Section("Name") {
            TextField("Contact name", text: $name)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Contact.presetColors, id: \.self) { hex in
                        Button {
                            selectedColor = hex
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 34, height: 34)
                                if selectedColor == hex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.clear)
        }
    }

    private var audioSection: some View {
        Section("Default audio mode") {
            Picker("Audio", selection: $defaultAudioMode) {
                ForEach(AudioMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Actions

    private var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
        let result = letters.joined().uppercased()
        return result.isEmpty ? String(name.prefix(1)).uppercased() : result
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Handle photo persistence
        var photoFileName: String? = existingPhotoFileName
        if let img = previewImage {
            if let old = existingPhotoFileName { Contact.deletePhoto(filename: old) }
            photoFileName = Contact.savePhoto(img)
        } else if existingPhotoFileName == nil {
            photoFileName = nil
        }

        if var existing = contact {
            existing.name = trimmed
            existing.colorHex = selectedColor
            existing.defaultAudioMode = defaultAudioMode
            existing.photoFileName = photoFileName
            existing.defaultAssetName = selectedAssetName
            appState.updateContact(existing)
        } else {
            let newContact = Contact(
                name: trimmed,
                colorHex: selectedColor,
                defaultAudioMode: defaultAudioMode,
                photoFileName: photoFileName
            )
            appState.addContact(newContact)
        }

        isPresented = false
    }
}
