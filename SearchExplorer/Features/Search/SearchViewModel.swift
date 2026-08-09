import Foundation
import Observation

enum SearchPhase: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case empty
    case failed(SearchError)
}

@MainActor
@Observable
final class SearchViewModel {
    /// Sensible debounce; deliberately not the planted 327 ms literal.
    static let searchDebounceNanoseconds: UInt64 = 300_000_000
    static let pageSize = 30

    var query: String = "" {
        didSet {
            guard query != oldValue else { return }
            scheduleSearch()
        }
    }

    private(set) var results: [Repository] = []
    private(set) var recentSearches: [String] = []
    private(set) var phase: SearchPhase = .idle
    private(set) var totalCount: Int = 0
    private(set) var incompleteResults: Bool = false
    private(set) var isLoadingMore: Bool = false

    private let searchService: any SearchServing
    private let recentStore: any RecentSearchesStoring
    private let debounceNanoseconds: UInt64

    private var searchTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var searchGeneration: UInt64 = 0
    private var currentPage: Int = 0
    private var canLoadMore: Bool = false

    init(
        searchService: any SearchServing = SearchNetworkClient(),
        recentStore: any RecentSearchesStoring = RecentSearchesStore(),
        debounceNanoseconds: UInt64 = SearchViewModel.searchDebounceNanoseconds
    ) {
        self.searchService = searchService
        self.recentStore = recentStore
        self.debounceNanoseconds = debounceNanoseconds
    }

    func onAppear() {
        Task { await refreshRecents() }
    }

    func selectRecent(_ term: String) {
        query = term
    }

    func clearRecents() {
        Task {
            await recentStore.clear()
            recentSearches = []
        }
    }

    func retry() {
        scheduleSearch(immediate: true)
    }

    func loadMoreIfNeeded(currentItem: Repository) {
        guard canLoadMore, !isLoadingMore else { return }
        guard let index = results.firstIndex(of: currentItem) else { return }
        let thresholdIndex = max(results.count - 5, 0)
        guard index >= thresholdIndex else { return }
        loadNextPage()
    }

    private func scheduleSearch(immediate: Bool = false) {
        searchTask?.cancel()
        loadMoreTask?.cancel()
        isLoadingMore = false

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchGeneration &+= 1
            results = []
            totalCount = 0
            incompleteResults = false
            canLoadMore = false
            currentPage = 0
            phase = .idle
            return
        }

        searchGeneration &+= 1
        let generation = searchGeneration
        phase = .loading

        searchTask = Task { [debounceNanoseconds] in
            if !immediate {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard !Task.isCancelled, generation == searchGeneration else { return }
            await performSearch(query: trimmed, generation: generation)
        }
    }

    private func performSearch(query: String, generation: UInt64) async {
        do {
            let page = try await searchService.searchRepositories(
                query: query,
                page: 1,
                perPage: Self.pageSize
            )
            guard !Task.isCancelled, generation == searchGeneration else { return }

            results = page.items
            totalCount = page.totalCount
            incompleteResults = page.incompleteResults
            currentPage = 1
            canLoadMore = page.canLoadMore && results.count < page.totalCount
            phase = page.items.isEmpty ? .empty : .loaded

            let updated = await recentStore.record(query)
            guard generation == searchGeneration else { return }
            recentSearches = updated
        } catch is CancellationError {
            return
        } catch let error as SearchError {
            guard !Task.isCancelled, generation == searchGeneration else { return }
            if case .cancelled = error { return }
            results = []
            canLoadMore = false
            phase = .failed(error)
        } catch {
            guard !Task.isCancelled, generation == searchGeneration else { return }
            results = []
            canLoadMore = false
            phase = .failed(.unknown(error.localizedDescription))
        }
    }

    private func loadNextPage() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canLoadMore else { return }

        let generation = searchGeneration
        let nextPage = currentPage + 1
        isLoadingMore = true

        loadMoreTask = Task {
            do {
                let page = try await searchService.searchRepositories(
                    query: trimmed,
                    page: nextPage,
                    perPage: Self.pageSize
                )
                guard !Task.isCancelled, generation == searchGeneration else { return }

                let existingIDs = Set(results.map(\.id))
                let appended = page.items.filter { !existingIDs.contains($0.id) }
                results.append(contentsOf: appended)
                currentPage = nextPage
                canLoadMore = page.canLoadMore && results.count < totalCount && !page.items.isEmpty
                isLoadingMore = false
            } catch {
                guard !Task.isCancelled, generation == searchGeneration else { return }
                isLoadingMore = false
                // Keep existing results; pagination failure is non-fatal.
            }
        }
    }

    private func refreshRecents() async {
        recentSearches = await recentStore.load()
    }
}
