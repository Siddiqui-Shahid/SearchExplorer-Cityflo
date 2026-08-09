import SwiftUI

struct RepositoryRowView: View {
    let repository: Repository

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: repository.ownerAvatarURL) { phase in
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
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(repository.fullName)
                    .font(.headline)
                    .lineLimit(1)
                if let description = repository.descriptionText, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 12) {
                    Label("\(repository.stars)", systemImage: "star")
                    if let language = repository.language {
                        Label(language, systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(.vertical, 4)
    }
}
