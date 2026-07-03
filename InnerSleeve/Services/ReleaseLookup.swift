import Foundation

struct ReleaseCandidate: Identifiable, Equatable {
    let id: String
    var artist: String
    var title: String
    var year: Int?
    var label: String?
    var catalogNumber: String?
    var format: String?
    var country: String?
    var barcode: String?
    var coverArtURL: URL?
    var tracks: [TrackCandidate]
}

struct TrackCandidate: Equatable, Identifiable {
    var id: String { "\(side?.rawValue ?? "-")-\(number)-\(title)" }
    var side: RecordSide?
    var number: Int
    var title: String
    var seconds: Int?
}

enum ReleaseLookupError: Error, Equatable, LocalizedError {
    case offline
    case notFound
    case rateLimited
    case decoding

    var errorDescription: String? {
        switch self {
        case .offline: return "Network unavailable."
        case .notFound: return "No matching release found."
        case .rateLimited: return "Catalog rate limit reached. Try again shortly."
        case .decoding: return "The catalog returned data Inner Sleeve could not read."
        }
    }
}

protocol ReleaseLookupService {
    func search(text: String) async throws -> [ReleaseCandidate]
    func search(barcode: String) async throws -> [ReleaseCandidate]
    func details(for candidate: ReleaseCandidate) async throws -> ReleaseCandidate
}

protocol CoverArtCandidateLookupService {
    func artworkCandidates(text: String) async throws -> [ReleaseCandidate]
}

enum ReleaseProvider: String, CaseIterable, Identifiable {
    case musicBrainz
    case discogs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .musicBrainz: return "MusicBrainz"
        case .discogs: return "Discogs"
        }
    }
}

enum ReleaseSideParser {
    static func side(from position: String?) -> RecordSide? {
        guard let first = position?.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return nil
        }
        switch first.uppercased() {
        case "A": return .a
        case "B": return .b
        default: return nil
        }
    }

    static func number(from position: String?, fallback: Int) -> Int {
        guard let position else { return fallback }
        let digits = position.drop { !$0.isNumber }.prefix { $0.isNumber }
        return Int(digits) ?? fallback
    }

    static func assignSidesIfMissing(_ tracks: [TrackCandidate]) -> [TrackCandidate] {
        guard tracks.contains(where: { $0.side == nil }) else { return tracks }
        let midpoint = Int(ceil(Double(tracks.count) / 2.0))
        return tracks.enumerated().map { index, track in
            var copy = track
            copy.side = index < midpoint ? .a : .b
            copy.number = index < midpoint ? index + 1 : index - midpoint + 1
            return copy
        }
    }
}

enum ReleaseSearchTuning {
    static func musicBrainzQuery(for text: String) -> String {
        let tokens = searchTokens(in: text)
        guard tokens.count >= 2, tokens.count <= 9 else {
            return text
        }

        let clauses = (1..<tokens.count).flatMap { split in
            let left = Array(tokens[..<split])
            let right = Array(tokens[split...])
            return [
                "(artist:(\(andClause(left))) AND release:(\(andClause(right))))",
                "(release:(\(andClause(left))) AND artist:(\(andClause(right))))",
            ]
        }

        return clauses.joined(separator: " OR ")
    }

    static func ranked(_ candidates: [ReleaseCandidate], for text: String) -> [ReleaseCandidate] {
        let tokens = searchTokens(in: text)
        guard tokens.count >= 2 else { return candidates }

        return candidates.enumerated()
            .sorted { lhs, rhs in
                let leftScore = score(lhs.element, tokens: tokens)
                let rightScore = score(rhs.element, tokens: tokens)
                if leftScore == rightScore {
                    return lhs.offset < rhs.offset
                }
                return leftScore > rightScore
            }
            .map(\.element)
    }

    static func deduplicatedByAlbum(_ candidates: [ReleaseCandidate]) -> [ReleaseCandidate] {
        var seenKeys = Set<String>()
        return candidates.filter { candidate in
            let key = "\(normalized(candidate.artist))|\(normalized(candidate.title))"
            guard !seenKeys.contains(key) else { return false }
            seenKeys.insert(key)
            return true
        }
    }

    private static func score(_ candidate: ReleaseCandidate, tokens: [String]) -> Int {
        let title = normalized(candidate.title)
        let artist = normalized(candidate.artist)
        var best = 0

        for split in 1..<tokens.count {
            let left = Array(tokens[..<split])
            let right = Array(tokens[split...])
            best = max(best, phraseScore(title, phraseTokens: left, titleWeight: true) + phraseScore(artist, phraseTokens: right, titleWeight: false))
            best = max(best, phraseScore(title, phraseTokens: right, titleWeight: true) + phraseScore(artist, phraseTokens: left, titleWeight: false))
        }

        return best
    }

    private static func phraseScore(_ value: String, phraseTokens: [String], titleWeight: Bool) -> Int {
        let phrase = phraseTokens.joined(separator: " ")
        let tokenHits = phraseTokens.filter { value.contains($0) }.count
        var score = tokenHits * (titleWeight ? 8 : 6)
        if value == phrase {
            score += titleWeight ? 120 : 70
        } else if value.contains(phrase) {
            score += titleWeight ? 80 : 45
        }
        return score
    }

    private static func searchTokens(in text: String) -> [String] {
        normalized(text)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func andClause(_ tokens: [String]) -> String {
        tokens.joined(separator: " AND ")
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber ? character : " "
            }
            .reduce(into: "") { result, character in
                if character == " ", result.last == " " {
                    return
                }
                result.append(character)
            }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
