import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showingContactsManager = false

    var body: some View {
        NavigationStack {
            Form {
                defaultsSection
                contactsSection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingContactsManager) {
                ContactsManagerView(isPresented: $showingContactsManager)
            }
        }
    }

    // MARK: - Sections

    private var defaultsSection: some View {
        Section("Call defaults") {
            @Bindable var state = appState

            Picker("Default audio", selection: $state.defaultAudioMode) {
                ForEach(AudioMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Toggle("Vibration", isOn: $state.vibrationEnabled)

            Picker("Voice language", selection: $state.voiceLanguage) {
                ForEach(VoiceLanguage.allCases) { lang in
                    Text(lang.rawValue).tag(lang)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var contactsSection: some View {
        Section("Contacts") {
            Button("Manage Contacts") {
                showingContactsManager = true
            }

            Button("Reset to Defaults", role: .destructive) {
                appState.contacts = Contact.defaults
                appState.saveContacts()
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0")
            LabeledContent("Delivery", value: "CallKit + Local Notification")

            VStack(alignment: .leading, spacing: 8) {
                Text("Privacy")
                    .font(.system(size: 14, weight: .semibold))
                Text("Rescue Me never makes real calls, sends data, or accesses your contacts. All data stays on device.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Contacts Manager

struct ContactsManagerView: View {
    @Binding var isPresented: Bool
    @Environment(AppState.self) private var appState
    @State private var editingContact: Contact?
    @State private var showAddContact = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(appState.contacts) { contact in
                    Button {
                        editingContact = contact
                    } label: {
                        HStack(spacing: 14) {
                            ContactAvatarView(contact: contact, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.name)
                                    .foregroundStyle(.primary)
                                    .font(.system(size: 16, weight: .medium))
                                Text("Default: \(contact.defaultAudioMode.rawValue)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .font(.system(size: 13))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in appState.deleteContacts(at: offsets) }
            }
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddContact = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(item: $editingContact) { contact in
                AddEditContactView(contact: contact, isPresented: .init(
                    get: { editingContact != nil },
                    set: { if !$0 { editingContact = nil } }
                ))
            }
            .sheet(isPresented: $showAddContact) {
                AddEditContactView(contact: nil, isPresented: $showAddContact)
            }
        }
    }
}
