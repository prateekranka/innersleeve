import Foundation

final class MusicBrainzService: ReleaseLookupService, CoverArtCandidateLookupService {
    private let session: URLSession
    private let throttle: RequestThrottle
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared, throttle: RequestThrottle = RequestThrottle(minimumDelay: 1.1)) {
        self.session = session
        self.throttle = throttle
    }

    func search(text: String) async throws -> [ReleaseCandidate] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return try await search(
            query: ReleaseSearchTuning.musicBrainzQuery(for: query),
            rankingText: query,
            deduplicateAlbums: true
        )
    }

    func search(barcode: String) async throws -> [ReleaseCandidate] {
        let cleaned = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }
        return try await search(query: "barcode:\(cleaned)", rankingText: nil)
    }

    func artworkCandidates(text: String) async throws -> [ReleaseCandidate] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return try await search(
            query: ReleaseSearchTuning.musicBrainzQuery(for: query),
            rankingText: query,
            deduplicateAlbums: false,
            limit: 25
        )
    }

    func details(for candidate: ReleaseCandidate) async throws -> ReleaseCandidate {
        let mbid = candidate.id.replacingOccurrences(of: "mb:", with: "")
        let url = URL(string: "https://musicbrainz.org/ws/2/release/\(mbid)?inc=recordings+labels+artist-credits&fmt=json")!
        let dto: ReleaseDTO = try await request(url)
        var detailed = dto.candidate
        if detailed.tracks.isEmpty {
            detailed.tracks = candidate.tracks
        }
        return detailed
    }

    private func search(
        query: String,
        rankingText: String?,
        deduplicateAlbums: Bool = false,
        limit: Int = 12
    ) async throws -> [ReleaseCandidate] {
        var components = URLComponents(string: "https://musicbrainz.org/ws/2/release/")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "fmt", value: "json"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        let dto: ReleaseSearchDTO = try await request(components.url!)
        let candidates = dto.releases.map(\.candidate)
        guard !candidates.isEmpty else { throw ReleaseLookupError.notFound }
        if let rankingText {
            let ranked = ReleaseSearchTuning.ranked(candidates, for: rankingText)
            return deduplicateAlbums ? ReleaseSearchTuning.deduplicatedByAlbum(ranked) : ranked
        }
        return candidates
    }

    private func request<T: Decodable>(_ url: URL) async throws -> T {
        await throttle.waitForTurn()
        var request = URLRequest(url: url)
        request.setValue("InnerSleeve/1.0 (https://innersleeve.app/contact)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ReleaseLookupError.offline }
            if http.statusCode == 404 { throw ReleaseLookupError.notFound }
            if http.statusCode == 503 || http.statusCode == 429 { throw ReleaseLookupError.rateLimited }
            guard 200..<300 ~= http.statusCode else { throw ReleaseLookupError.offline }
            do { return try decoder.decode(T.self, from: data) } catch { throw ReleaseLookupError.decoding }
        } catch let error as ReleaseLookupError {
            throw error
        } catch {
            throw ReleaseLookupError.offline
        }
    }
}

actor RequestThrottle {
    private let minimumDelay: TimeInterval
    private var lastRequest: Date?

    init(minimumDelay: TimeInterval) {
        self.minimumDelay = minimumDelay
    }

    func waitForTurn() async {
        if let lastRequest {
            let elapsed = Date().timeIntervalSince(lastRequest)
            if elapsed < minimumDelay {
                try? await Task.sleep(for: .milliseconds(Int((minimumDelay - elapsed) * 1000)))
            }
        }
        lastRequest = Date()
    }
}

private struct ReleaseSearchDTO: Decodable {
    var releases: [ReleaseDTO]
}

private struct ReleaseDTO: Decodable {
    var id: String
    var title: String
    var date: String?
    var country: String?
    var barcode: String?
    var media: [MediumDTO]?
    var labelInfo: [LabelInfoDTO]?
    var artistCredit: [ArtistCreditDTO]?

    enum CodingKeys: String, CodingKey {
        case id, title, date, country, barcode, media
        case labelInfo = "label-info"
        case artistCredit = "artist-credit"
    }

    var candidate: ReleaseCandidate {
        let tracks = ReleaseSideParser.assignSidesIfMissing((media ?? []).flatMap { medium in
            (medium.tracks ?? []).enumerated().map { offset, track in
                let side = ReleaseSideParser.side(from: track.position)
                return TrackCandidate(
                    side: side,
                    number: ReleaseSideParser.number(from: track.position, fallback: offset + 1),
                    title: track.title,
                    seconds: track.length.map { $0 / 1000 }
                )
            }
        })
        let label = labelInfo?.first?.label?.name
        let catalogNumber = labelInfo?.first?.catalogNumber
        let year = date.flatMap { Int($0.prefix(4)) }
        return ReleaseCandidate(
            id: "mb:\(id)",
            artist: artistCredit?.map(\.name).joined(separator: "") ?? "Unknown artist",
            title: title,
            year: year,
            label: label,
            catalogNumber: catalogNumber,
            format: media?.first?.format,
            country: country,
            barcode: barcode,
            coverArtURL: URL(string: "https://coverartarchive.org/release/\(id)/front-1200"),
            tracks: tracks
        )
    }
}

private struct ArtistCreditDTO: Decodable {
    var name: String
}

private struct LabelInfoDTO: Decodable {
    var catalogNumber: String?
    var label: LabelDTO?

    enum CodingKeys: String, CodingKey {
        case catalogNumber = "catalog-number"
        case label
    }
}

private struct LabelDTO: Decodable {
    var name: String?
}

private struct MediumDTO: Decodable {
    var format: String?
    var tracks: [TrackDTO]?
}

private struct TrackDTO: Decodable {
    var position: String?
    var title: String
    var length: Int?
}
