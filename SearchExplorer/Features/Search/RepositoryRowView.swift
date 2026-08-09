import SwiftUI

struct RepositoryRowView: View {
    let repository: Repository

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            OwnerAvatarView(url: repository.ownerAvatarURL)

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
                .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    private var rowAccessibilityLabel: String {
        var parts = [repository.fullName]
        if let description = repository.descriptionText, !description.isEmpty {
            parts.append(description)
        }
        parts.append("\(repository.stars) stars")
        if let language = repository.language {
            parts.append(language)
        }
        return parts.joined(separator: ". ")
    }
}
