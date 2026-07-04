import SwiftUI

struct CatalogSearchView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var query = ""
    @State private var results: [ReleaseCandidate] = []
    @State private var isLoading = false
    @State private var errorText: String?
    var onSelect: (ReleaseCandidate) -> Void

    var body: some View {
        List {
            Section {
                TextField("Search artist, title, barcode", text: $query)
                    .textInputAutocapitalization(.words)
            }
            if let errorText {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.orangeAccent)
            }
            if isLoading {
                ProgressView()
            }
            ForEach(results) { candidate in
                Button {
                    Task { await select(candidate) }
                } label: {
                    CandidateRow(candidate: candidate)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Search catalog")
        .task(id: query) { await search() }
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            results = []
            errorText = nil
            isLoading = false
            return
        }
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        isLoading = true
        errorText = nil
        do {
            let found = try await settings.makeLookupService().search(text: trimmed)
            guard !Task.isCancelled else { return }
            results = found
        } catch {
            // A superseded keystroke's request fails with a cancellation
            // error; it must not clobber the newer search's state.
            guard !Task.isCancelled else { return }
            results = []
            errorText = (error as? LocalizedError)?.errorDescription ?? "Catalog lookup failed. Manual entry is still available."
        }
        isLoading = false
    }

    private func select(_ candidate: ReleaseCandidate) async {
        isLoading = true
        defer { isLoading = false }
        do {
            onSelect(try await settings.makeLookupService().details(for: candidate))
        } catch {
            onSelect(candidate)
        }
    }
}

private struct CandidateRow: View {
    var candidate: ReleaseCandidate

    var body: some View {
        HStack(spacing: 12) {
            CandidateArtwork(candidate: candidate)
                .frame(width: 62, height: 62)
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                Text([candidate.artist, candidate.year.map(String.init), candidate.label].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct CandidateArtwork: View {
    var candidate: ReleaseCandidate

    var body: some View {
        ZStack {
            if let url = candidate.coverArtURL {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.18))) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                    case .empty:
                        fallback
                            .opacity(0.45)
                            .redacted(reason: .placeholder)
                    case .failure:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .clipShape(.rect(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Palette.offWhite.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Palette.warmShadow.opacity(0.18), radius: 4, y: 2)
    }

    private var fallback: some View {
        CoverArtView(
            seed: RecordDraft.stableArtSeed(artist: candidate.artist, title: candidate.title),
            style: .rings,
            initials: candidate.artist.artInitials,
            titleText: candidate.title
        )
    }
}
