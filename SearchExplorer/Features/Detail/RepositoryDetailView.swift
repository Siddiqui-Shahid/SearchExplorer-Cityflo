import SwiftUI

struct RepositoryDetailView: View {
    let repository: Repository

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    OwnerAvatarView(url: repository.ownerAvatarURL, side: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(repository.name)
                            .font(.title2.bold())
                        Text(repository.ownerLogin)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(repository.name), by \(repository.ownerLogin)")
                }
                .padding(.vertical, 4)
            }

            if let description = repository.descriptionText, !description.isEmpty {
                Section("About") {
                    Text(description)
                }
            }

            Section("Stats") {
                LabeledContent("Stars", value: "\(repository.stars)")
                LabeledContent("Forks", value: "\(repository.forks)")
                LabeledContent("Open issues", value: "\(repository.openIssues)")
                if let language = repository.language {
                    LabeledContent("Language", value: language)
                }
                if let updated = repository.updatedAt {
                    LabeledContent("Updated", value: updated.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section {
                Link(destination: repository.htmlURL) {
                    Label("Open on GitHub", systemImage: "safari")
                }
                .accessibilityHint("Opens this repository in Safari")
            }
        }
        .navigationTitle(repository.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
