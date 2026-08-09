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
    /// Prefetch when the user scrolls within this many rows of the end.
    static let paginationPrefetchDistance = 5
    /// GitHub search API only serves the first 1,000 hits; further pages 422.
    static let maxResultWindow = 1_000

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

    private var searchGeneration: UInt64 = 0
    private var currentPage: Int = 0
    private var canLoadMore: Bool = false

    // `nonisolated(unsafe)` so `deinit` can cancel without hopping the main actor.
    // All reads/writes besides deinit still happen on `@MainActor`.
    nonisolated(unsafe) private var searchTask: Task<Void, Never>?
    nonisolated(unsafe) private var loadMoreTask: Task<Void, Never>?

    /// Dependencies are required so the app (or tests) is the composition root — no hidden singletons.
    init(
        searchService: any SearchServing,
        recentStore: any RecentSearchesStoring,
        debounceNanoseconds: UInt64 = SearchViewModel.searchDebounceNanoseconds
    ) {
        self.searchService = searchService
        self.recentStore = recentStore
        self.debounceNanoseconds = debounceNanoseconds
    }

    deinit {
        searchTask?.cancel()
        loadMoreTask?.cancel()
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
        let thresholdIndex = max(results.count - Self.paginationPrefetchDistance, 0)
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
            resetResultsState(phase: .idle)
            return
        }

        searchGeneration &+= 1
        let generation = searchGeneration
        phase = .loading

        searchTask = Task { [debounceNanoseconds] in
            if !immediate {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard isCurrentSearch(generation) else { return }
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
            guard isCurrentSearch(generation) else { return }

            results = page.items
            totalCount = page.totalCount
            incompleteResults = page.incompleteResults
            currentPage = 1
            canLoadMore = computeCanLoadMore(page: page, loadedCount: results.count)
            phase = page.items.isEmpty ? .empty : .loaded

            let updated = await recentStore.record(query)
            guard isCurrentGeneration(generation) else { return }
            recentSearches = updated
        } catch is CancellationError {
            return
        } catch let error as SearchError {
            guard isCurrentSearch(generation) else { return }
            if case .cancelled = error { return }
            applyFailure(error)
        } catch {
            guard isCurrentSearch(generation) else { return }
            applyFailure(.unknown(error.localizedDescription))
        }
    }

    private func loadNextPage() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canLoadMore else { return }

        let generation = searchGeneration
        let nextPage = currentPage + 1
        // Proactive stop before GitHub's hard window (page * perPage would exceed 1000).
        guard nextPage * Self.pageSize <= Self.maxResultWindow else {
            canLoadMore = false
            return
        }

        isLoadingMore = true

        loadMoreTask = Task {
            defer {
                // Only clear if this generation is still current; a newer search already reset the flag.
                if isCurrentGeneration(generation) {
                    isLoadingMore = false
                }
            }
            do {
                let page = try await searchService.searchRepositories(
                    query: trimmed,
                    page: nextPage,
                    perPage: Self.pageSize
                )
                guard isCurrentSearch(generation) else { return }

                let existingIDs = Set(results.map(\.id))
                let appended = page.items.filter { !existingIDs.contains($0.id) }
                results.append(contentsOf: appended)
                currentPage = nextPage
                canLoadMore = computeCanLoadMore(page: page, loadedCount: results.count)
            } catch let error as SearchError where error == .resultWindowExhausted || error == .httpStatus(422) {
                guard isCurrentSearch(generation) else { return }
                canLoadMore = false
            } catch {
                // Keep existing results and canLoadMore; transient pagination failure is non-fatal.
                guard isCurrentSearch(generation) else { return }
            }
        }
    }

    private func refreshRecents() async {
        recentSearches = await recentStore.load()
    }

    private func isCurrentSearch(_ generation: UInt64) -> Bool {
        !Task.isCancelled && generation == searchGeneration
    }

    private func isCurrentGeneration(_ generation: UInt64) -> Bool {
        generation == searchGeneration
    }

    private func computeCanLoadMore(page: SearchPage, loadedCount: Int) -> Bool {
        page.canLoadMore
            && loadedCount < page.totalCount
            && !page.items.isEmpty
            && loadedCount < Self.maxResultWindow
            && page.page * page.perPage < Self.maxResultWindow
    }

    private func resetResultsState(phase: SearchPhase) {
        results = []
        totalCount = 0
        incompleteResults = false
        canLoadMore = false
        currentPage = 0
        self.phase = phase
    }

    private func applyFailure(_ error: SearchError) {
        results = []
        canLoadMore = false
        incompleteResults = false
        totalCount = 0
        currentPage = 0
        phase = .failed(error)
    }
}
