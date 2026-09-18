import SwiftUI

struct ContactsGridView: View {
    @Environment(AppState.self) private var appState

    // Three independent sheet triggers — never share state between them.
    @State private var schedulingContact: Contact?   // → ScheduleModalView
    @State private var editingContact: Contact?      // → AddEditContactView (edit)
    @State private var showNewContact = false         // → AddEditContactView (new)

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(appState.contacts) { contact in
                            ContactCard(contact: contact) {
                                schedulingContact = contact
                            }
                            .contextMenu {
                                Button {
                                    editingContact = contact
                                } label: { Label("Edit", systemImage: "pencil") }

                                Button(role: .destructive) {
                                    if let idx = appState.contacts.firstIndex(where: { $0.id == contact.id }) {
                                        appState.deleteContacts(at: IndexSet(integer: idx))
                                    }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                        }

                        addButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, appState.callPhase == .countdown ? 100 : 24)
                }

                if appState.callPhase == .countdown {
                    countdownBanner
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35), value: appState.callPhase)
            .navigationTitle("Rescue Me")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showNewContact = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // Schedule sheet — keyed on the contact identity
            .sheet(item: $schedulingContact) { contact in
                ScheduleModalView(contact: contact, isPresented: .init(
                    get: { schedulingContact != nil },
                    set: { if !$0 { schedulingContact = nil } }
                ))
            }
            // Edit sheet — keyed on the contact identity
            .sheet(item: $editingContact) { contact in
                AddEditContactView(contact: contact, isPresented: .init(
                    get: { editingContact != nil },
                    set: { if !$0 { editingContact = nil } }
                ))
            }
            // New-contact sheet — keyed on a bool
            .sheet(isPresented: $showNewContact) {
                AddEditContactView(contact: nil, isPresented: $showNewContact)
            }
        }
    }

    private var addButton: some View {
        Button { showNewContact = true } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: 72, height: 72)
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text("Add Contact")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var countdownBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "phone.fill")
                .foregroundStyle(Theme.callGreen)
                .font(.system(size: 16))

            if let contact = appState.currentContact {
                Text("Call from \(contact.name) in \(Int(appState.countdownRemaining))s…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Button("Cancel") {
                appState.cancelScheduled()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}
