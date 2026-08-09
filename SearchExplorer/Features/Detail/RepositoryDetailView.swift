import SwiftUI

struct RepositoryDetailView: View {
    let repository: Repository

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    AsyncImage(url: repository.ownerAvatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Image(systemName: "person.crop.circle")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(repository.name)
                            .font(.title2.bold())
                        Text(repository.ownerLogin)
                            .foregroundStyle(.secondary)
                    }
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
            }
        }
        .navigationTitle(repository.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
