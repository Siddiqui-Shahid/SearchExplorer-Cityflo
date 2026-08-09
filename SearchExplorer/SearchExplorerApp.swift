import SwiftUI

@main
struct SearchExplorerApp: App {
    @State private var viewModel = SearchViewModel(
        searchService: SearchNetworkClient(),
        recentStore: RecentSearchesStore()
    )

    var body: some Scene {
        WindowGroup {
            SearchView(viewModel: viewModel)
        }
    }
}
