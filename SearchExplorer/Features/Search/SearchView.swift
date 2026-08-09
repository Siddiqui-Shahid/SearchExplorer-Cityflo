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
                        .accessibilityLabel("Searching repositories")
                case .empty:
                    ContentUnavailableView.search(text: viewModel.query)
                case .failed(let error):
                    failureContent(error)
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
                            .accessibilityHint("Removes all saved recent searches")
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
                        .accessibilityHint("Runs this search again")
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func failureContent(_ error: SearchError) -> some View {
        ContentUnavailableView {
            Label(error.title, systemImage: error.systemImage)
        } description: {
            Text(error.userMessage)
        } actions: {
            Button("Retry") { viewModel.retry() }
                .accessibilityHint("Runs the current search again")
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
                    .accessibilityLabel("Warning: results may be incomplete because GitHub timed out the search")
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
                            .accessibilityLabel("Loading more repositories")
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
                    .accessibilityLabel("Updating search results")
            }
        }
    }
}

#Preview {
    SearchView(
        viewModel: SearchViewModel(
            searchService: SearchNetworkClient(),
            recentStore: RecentSearchesStore()
        )
    )
}
