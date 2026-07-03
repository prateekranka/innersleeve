import Foundation

final class DiscogsService: ReleaseLookupService {
    private let tokenProvider: () -> String
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(tokenProvider: @escaping () -> String, session: URLSession = .shared) {
        self.tokenProvider = tokenProvider
        self.session = session
    }

    static func validate(token: String, session: URLSession = .shared) async -> DiscogsTokenValidationResult {
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return .missing }
        var request = URLRequest(url: URL(string: "https://api.discogs.com/oauth/identity")!)
        request.setValue("Discogs token=\(token)", forHTTPHeaderField: "Authorization")
        request.setValue("InnerSleeve/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .offline }
            if http.statusCode == 401 || http.statusCode == 403 { return .rejected }
            if http.statusCode == 429 || http.statusCode == 503 { return .rateLimited }
            guard 200..<300 ~= http.statusCode else { return .offline }
            return .accepted(remaining: http.value(forHTTPHeaderField: "x-discogs-ratelimit-remaining"))
        } catch {
            return .offline
        }
    }

    func search(text: String) async throws -> [ReleaseCandidate] {
        try await search(queryItems: [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "type", value: "release"),
        ])
    }

    func search(barcode: String) async throws -> [ReleaseCandidate] {
        try await search(queryItems: [
            URLQueryItem(name: "barcode", value: barcode),
            URLQueryItem(name: "type", value: "release"),
        ])
    }

    func details(for candidate: ReleaseCandidate) async throws -> ReleaseCandidate {
        let id = candidate.id.replacingOccurrences(of: "dc:", with: "")
        let dto: DiscogsReleaseDTO = try await request(URL(string: "https://api.discogs.com/releases/\(id)")!)
        return dto.candidate(fallback: candidate)
    }

    private func search(queryItems: [URLQueryItem]) async throws -> [ReleaseCandidate] {
        var components = URLComponents(string: "https://api.discogs.com/database/search")!
        components.queryItems = queryItems
        let dto: DiscogsSearchDTO = try await request(components.url!)
        let candidates = dto.results.map(\.candidate)
        guard !candidates.isEmpty else { throw ReleaseLookupError.notFound }
        return candidates
    }

    private func request<T: Decodable>(_ url: URL) async throws -> T {
        let token = tokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw ReleaseLookupError.notFound }
        var request = URLRequest(url: url)
        request.setValue("Discogs token=\(token)", forHTTPHeaderField: "Authorization")
        request.setValue("InnerSleeve/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ReleaseLookupError.offline }
            if http.value(forHTTPHeaderField: "x-discogs-ratelimit-remaining") == "0" {
                throw ReleaseLookupError.rateLimited
            }
            if http.statusCode == 404 { throw ReleaseLookupError.notFound }
            if http.statusCode == 429 || http.statusCode == 503 { throw ReleaseLookupError.rateLimited }
            guard 200..<300 ~= http.statusCode else { throw ReleaseLookupError.offline }
            do { return try decoder.decode(T.self, from: data) } catch { throw ReleaseLookupError.decoding }
        } catch let error as ReleaseLookupError {
            throw error
        } catch {
            throw ReleaseLookupError.offline
        }
    }
}

enum DiscogsTokenValidationResult: Equatable {
    case accepted(remaining: String?)
    case missing
    case rejected
    case rateLimited
    case offline
}

private struct DiscogsSearchDTO: Decodable {
    var results: [DiscogsResultDTO]
}

private struct DiscogsResultDTO: Decodable {
    var id: Int
    var title: String
    var year: Int?
    var label: [String]?
    var catno: String?
    var country: String?
    var barcode: [String]?
    var coverImage: String?

    enum CodingKeys: String, CodingKey {
        case id, title, year, label, catno, country, barcode
        case coverImage = "cover_image"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        title = (try? container.decode(String.self, forKey: .title)) ?? "Unknown release"
        year = try container.decodeFlexibleInt(forKey: .year)
        label = try container.decodeFlexibleStringArray(forKey: .label)
        catno = try container.decodeFlexibleString(forKey: .catno)
        country = try container.decodeFlexibleString(forKey: .country)
        barcode = try container.decodeFlexibleStringArray(forKey: .barcode)
        coverImage = try container.decodeFlexibleString(forKey: .coverImage)
    }

    var candidate: ReleaseCandidate {
        let parts = title.components(separatedBy: " - ")
        let artist = parts.count > 1 ? parts[0] : "Unknown artist"
        let releaseTitle = parts.count > 1 ? parts.dropFirst().joined(separator: " - ") : title
        return ReleaseCandidate(
            id: "dc:\(id)",
            artist: artist,
            title: releaseTitle,
            year: year,
            label: label?.first,
            catalogNumber: catno,
            format: nil,
            country: country,
            barcode: barcode?.first,
            coverArtURL: coverImage.flatMap(URL.init(string:)),
            tracks: []
        )
    }
}

private struct DiscogsReleaseDTO: Decodable {
    var id: Int
    var title: String
    var year: Int?
    var country: String?
    var labels: [DiscogsLabelDTO]?
    var formats: [DiscogsFormatDTO]?
    var artists: [DiscogsArtistDTO]?
    var tracklist: [DiscogsTrackDTO]?
    var images: [DiscogsImageDTO]?

    enum CodingKeys: String, CodingKey {
        case id, title, year, country, labels, formats, artists, tracklist, images
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        title = (try? container.decode(String.self, forKey: .title)) ?? "Unknown release"
        year = try container.decodeFlexibleInt(forKey: .year)
        country = try container.decodeFlexibleString(forKey: .country)
        labels = try? container.decode([DiscogsLabelDTO].self, forKey: .labels)
        formats = try? container.decode([DiscogsFormatDTO].self, forKey: .formats)
        artists = try? container.decode([DiscogsArtistDTO].self, forKey: .artists)
        tracklist = try? container.decode([DiscogsTrackDTO].self, forKey: .tracklist)
        images = try? container.decode([DiscogsImageDTO].self, forKey: .images)
    }

    func candidate(fallback: ReleaseCandidate) -> ReleaseCandidate {
        let tracks = ReleaseSideParser.assignSidesIfMissing((tracklist ?? []).enumerated().compactMap { offset, track in
            guard track.type_ == nil || track.type_ == "track" else { return nil }
            return TrackCandidate(
                side: ReleaseSideParser.side(from: track.position),
                number: ReleaseSideParser.number(from: track.position, fallback: offset + 1),
                title: track.title,
                seconds: seconds(from: track.duration)
            )
        })
        let coverArtURL = images?.first { $0.isPrimary }?.preferredURL
            ?? images?.compactMap(\.preferredURL).first
            ?? fallback.coverArtURL

        return ReleaseCandidate(
            id: "dc:\(id)",
            artist: artists?.map(\.name).joined(separator: ", ") ?? fallback.artist,
            title: title,
            year: year ?? fallback.year,
            label: labels?.first?.name ?? fallback.label,
            catalogNumber: labels?.first?.catno ?? fallback.catalogNumber,
            format: formats?.first?.name ?? fallback.format,
            country: country ?? fallback.country,
            barcode: fallback.barcode,
            coverArtURL: coverArtURL,
            tracks: tracks
        )
    }

    private func seconds(from duration: String?) -> Int? {
        guard let duration else { return nil }
        if let seconds = Int(duration) {
            return seconds
        }
        guard duration.contains(":") else { return nil }
        let parts = duration.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }
}

private struct DiscogsLabelDTO: Decodable {
    var name: String?
    var catno: String?

    enum CodingKeys: String, CodingKey {
        case name, catno
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeFlexibleString(forKey: .name)
        catno = try container.decodeFlexibleString(forKey: .catno)
    }
}

private struct DiscogsFormatDTO: Decodable {
    var name: String?

    enum CodingKeys: String, CodingKey {
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeFlexibleString(forKey: .name)
    }
}

private struct DiscogsArtistDTO: Decodable {
    var name: String

    enum CodingKeys: String, CodingKey {
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try container.decodeFlexibleString(forKey: .name)) ?? "Unknown artist"
    }
}

private struct DiscogsTrackDTO: Decodable {
    var position: String?
    var title: String
    var duration: String?
    var type_: String?

    enum CodingKeys: String, CodingKey {
        case position, title, duration, type_
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        position = try container.decodeFlexibleString(forKey: .position)
        title = (try container.decodeFlexibleString(forKey: .title)) ?? "Untitled"
        duration = try container.decodeFlexibleString(forKey: .duration)
        type_ = try container.decodeFlexibleString(forKey: .type_)
    }
}

private struct DiscogsImageDTO: Decodable {
    var uri: String?
    var uri150: String?
    var type: String?

    enum CodingKeys: String, CodingKey {
        case uri, uri150, type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uri = try container.decodeFlexibleString(forKey: .uri)
        uri150 = try container.decodeFlexibleString(forKey: .uri150)
        type = try container.decodeFlexibleString(forKey: .type)
    }

    var preferredURL: URL? {
        uri.flatMap(URL.init(string:)) ?? uri150.flatMap(URL.init(string:))
    }

    var isPrimary: Bool {
        type?.localizedCaseInsensitiveCompare("primary") == .orderedSame
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) throws -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        if let values = try? decodeIfPresent([String].self, forKey: key) {
            return values.first
        }
        if let values = try? decodeIfPresent([Int].self, forKey: key) {
            return values.first.map(String.init)
        }
        return nil
    }

    func decodeFlexibleStringArray(forKey key: Key) throws -> [String]? {
        if let values = try? decodeIfPresent([String].self, forKey: key) {
            return values
        }
        if let values = try? decodeIfPresent([Int].self, forKey: key) {
            return values.map(String.init)
        }
        if let value = try decodeFlexibleString(forKey: key) {
            return [value]
        }
        return nil
    }

    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }
}
