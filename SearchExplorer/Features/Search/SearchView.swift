import SwiftUI

struct SearchView: View {
    @Bindable var viewModel: SearchViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .idle:
                    idleContent
                case .loading where viewModel.results.isEmpty:
                    ProgressView("Searching…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    ContentUnavailableView.search(text: viewModel.query)
                case .failed(let error):
                    ContentUnavailableView {
                        Label("Search failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.userMessage)
                    } actions: {
                        Button("Retry") { viewModel.retry() }
                    }
                case .loading, .loaded:
                    resultsList
                }
            }
            .navigationTitle("Repo Explorer")
            .navigationDestination(for: Repository.self) { repo in
                RepositoryDetailView(repository: repo)
            }
            .searchable(
                text: $viewModel.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search GitHub repositories"
            )
            .toolbar {
                if !viewModel.recentSearches.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear Recents") { viewModel.clearRecents() }
                    }
                }
            }
        }
        .onAppear { viewModel.onAppear() }
    }

    @ViewBuilder
    private var idleContent: some View {
        if viewModel.recentSearches.isEmpty {
            ContentUnavailableView(
                "Search GitHub",
                systemImage: "magnifyingglass",
                description: Text("Find repositories by name, topic, or description. Recent searches will appear here.")
            )
        } else {
            List {
                Section("Recent searches") {
                    ForEach(viewModel.recentSearches, id: \.self) { term in
                        Button {
                            viewModel.selectRecent(term)
                        } label: {
                            Label(term, systemImage: "clock.arrow.circlepath")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var resultsList: some View {
        List {
            if viewModel.incompleteResults {
                Section {
                    Label(
                        "Results may be incomplete (GitHub timed out the search).",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(viewModel.results) { repo in
                    NavigationLink(value: repo) {
                        RepositoryRowView(repository: repo)
                    }
                    .onAppear {
                        viewModel.loadMoreIfNeeded(currentItem: repo)
                    }
                }
            } header: {
                Text("\(viewModel.totalCount) repositories")
            } footer: {
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.phase == .loading && !viewModel.results.isEmpty {
                ProgressView()
                    .padding(12)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }
}

#Preview {
    SearchView(viewModel: SearchViewModel())
}
