import Foundation

struct CoverArtFetchResult: Equatable {
    var data: Data
    var sourceURL: URL
}

final class CoverArtRefetcher {
    private let lookupService: ReleaseLookupService
    private let loader: CoverArtDataLoading

    init(
        lookupService: ReleaseLookupService = MusicBrainzService(),
        loader: CoverArtDataLoading = CoverArtLoader()
    ) {
        self.lookupService = lookupService
        self.loader = loader
    }

    func refetch(savedURL: URL?, artist: String, title: String, forceLookup: Bool) async -> CoverArtFetchResult? {
        var urls = [URL]()
        if let savedURL {
            urls.append(contentsOf: Self.artworkURLFallbacks(for: savedURL))
        }

        if forceLookup {
            let query = "\(artist) \(title)"
            let candidates: [ReleaseCandidate]?
            if let artworkLookup = lookupService as? CoverArtCandidateLookupService {
                candidates = try? await artworkLookup.artworkCandidates(text: query)
            } else {
                candidates = try? await lookupService.search(text: query)
            }

            if let candidates {
                for candidate in candidates {
                    guard let coverArtURL = candidate.coverArtURL else { continue }
                    urls.append(contentsOf: Self.artworkURLFallbacks(for: coverArtURL))
                }
            }
        }

        for url in Self.uniqued(urls) {
            if let data = try? await loader.loadData(from: url) {
                return CoverArtFetchResult(data: data, sourceURL: url)
            }
        }
        return nil
    }

    static func artworkURLFallbacks(for url: URL) -> [URL] {
        let urlString = url.absoluteString
        guard urlString.contains("coverartarchive.org"),
              urlString.hasSuffix("/front-1200") else {
            return [url]
        }

        return [
            url,
            URL(string: String(urlString.dropLast(4)) + "500"),
            URL(string: String(urlString.dropLast(5))),
        ].compactMap(\.self)
    }

    private static func uniqued(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { url in
            guard !seen.contains(url.absoluteString) else { return false }
            seen.insert(url.absoluteString)
            return true
        }
    }
}
