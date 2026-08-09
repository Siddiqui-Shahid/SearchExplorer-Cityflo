import SwiftUI

/// Shared avatar for list rows and detail.
struct OwnerAvatarView: View {
    let url: URL?
    var side: CGFloat = 40

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            case .empty:
                ProgressView()
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side * 0.2, style: .continuous))
        .background(
            Color.secondary.opacity(0.12),
            in: RoundedRectangle(cornerRadius: side * 0.2, style: .continuous)
        )
        .accessibilityHidden(true)
    }
}
