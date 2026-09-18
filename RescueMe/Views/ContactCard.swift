import SwiftUI

struct ContactCard: View {
    let contact: Contact
    let action: () -> Void

    @State private var photo: UIImage?

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                avatarView
                    .frame(width: 72, height: 72)
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

                Text(contact.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .task(id: contact.photoFileName) {
            photo = contact.loadPhoto()
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else if let assetName = contact.defaultAssetName,
                  let assetImage = UIImage(named: assetName) {
            Image(uiImage: assetImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            ZStack {
                Circle().fill(Color(hex: contact.colorHex))
                if let emoji = contact.emoji {
                    Text(emoji)
                        .font(.system(size: 38))
                } else {
                    Text(contact.initials)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
