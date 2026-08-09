import SwiftUI

@main
struct SearchExplorerApp: App {
    @State private var viewModel = SearchViewModel()

    var body: some Scene {
        WindowGroup {
            SearchView(viewModel: viewModel)
        }
    }
}
