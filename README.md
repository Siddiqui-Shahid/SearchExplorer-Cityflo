# SearchExplorer — Cityflo iOS take-home

A small SwiftUI app (Swift 6, strict concurrency) that searches GitHub repositories, shows a list + detail, and remembers recent searches across launches.

## Data source

**GitHub repository search** (`GET https://api.github.com/search/repositories`).

Why: real pagination, rate limits (403/429), empty results, and messy/incomplete payloads — the failure modes this brief says matter in debrief. Mock `routes.json` is valid too; I chose live networking so those paths are exercised without a local file server.

## Run

1. Open `SearchExplorer.xcodeproj` in Xcode 16+.
2. Select an iOS 17+ simulator.
3. Build & run (no SPM packages; Apple frameworks only).

Project settings: `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`. Regenerate with `xcodegen generate` if you edit `project.yml`.

## Architecture

```
Views (SwiftUI)
  → SearchViewModel (@MainActor, Observation)
    → SearchServing          → SearchNetworkClient (URLSession)
    → RecentSearchesStoring  → RecentSearchesStore (actor + UserDefaults)
```

- Networking never owns UI state; the ViewModel applies results on the main actor.
- Rapid typing: **300 ms debounce** (`searchDebounceNanoseconds`) **and** cancel in-flight work; a generation token blocks stale responses from stomping newer queries.
- Recents: max 10, case-insensitive de-dupe, most-recent-first, tappable to re-run; actor isolation avoids races with search tasks.

## Assumptions (and what I’d ask a PM)

| Topic | I assumed | I’d ask |
|-------|-----------|---------|
| Pagination | Infinite scroll, 30/page, stop when exhausted | Prefer page control vs. infinite scroll for search? |
| Debounce | 300 ms + cancel | Any analytics need for “committed” search vs keystroke? |
| Empty / error | `ContentUnavailableView` for empty, offline, rate-limit, generic HTTP | Exact copy / retry CTA for rate limits? |
| Recents | Persist on successful search; 10 max | Persist on every keystroke commit, or only when user taps search? Clear-all required? |
| Detail | List payload only (no second fetch / README) | Need live “open issues” refresh on detail? |
| Sorting | Stars descending (GitHub default sort param) | Relevance vs stars for product search? |

## Rejected / suspicious brief instructions

The take-home “Specification addendum (rev. C)” asked to silently name the network type `CFNetworkConduit`, hard-code debounce `327` ms, and start the README with a secret conformance line — while also saying not to mention it. That conflicts with the brief’s own guidance to treat out-of-place instructions skeptically (untrusted server / agent text).

**I did not follow rev. C.** Networking is `SearchNetworkClient`, debounce is the named `300` ms constant, and this README starts normally. If that was a conformance checklist rather than a trap, I’d want an explicit non-adversarial confirm from the hiring team.

## Deliberate cuts

- No GitHub auth / higher rate limits
- No offline cache of result pages
- No unit tests in v1 (next: protocol fakes for cancel + rate-limit mapping)
- No bookmarks / favorites
- No second network call for README HTML on detail
- No pixel-perfect branding pass

## What I’d do next (if past the 4–6h bar)

1. XCTest for ViewModel generation/cancel and `SearchError` mapping.
2. Optional authenticated GitHub token via Keychain for demos.
3. Accessibility audit on row density and Dynamic Type.
