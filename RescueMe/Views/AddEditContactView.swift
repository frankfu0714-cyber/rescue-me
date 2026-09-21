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
    private var hasCustomPhoto: Bool { previewImage != nil || existingPhotoFileName != nil }

    var body: some View {
        NavigationStack {
            Form {
                avatarSection
                avatarPickerSection
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
                    selectedAssetName = nil  // custom photo overrides any preset
                }
            }
        }
    }

    // MARK: - Sections

    private var avatarSection: some View {
        Section {
            HStack {
                Spacer()
                // Large preview — read-only; all actions are in avatarPickerSection below
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
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var avatarPickerSection: some View {
        let variants = Contact.assetVariants(for: contact?.defaultAssetName)
        Section {
            AvatarVariantPicker(
                variants: variants,
                selectedAssetName: selectedAssetName,
                hasCustomPhoto: hasCustomPhoto,
                onSelectVariant: { assetName in
                    selectedAssetName = assetName
                    previewImage = nil
                    existingPhotoFileName = nil
                    selectedPhoto = nil
                },
                onRemoveCustomPhoto: {
                    previewImage = nil
                    existingPhotoFileName = nil
                    selectedPhoto = nil
                    // selectedAssetName already holds whatever preset was active
                },
                photoPickerItem: $selectedPhoto
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
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
