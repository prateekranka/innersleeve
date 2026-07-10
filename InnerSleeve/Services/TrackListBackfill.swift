import Foundation
import SwiftData

/// Fills in Side A/B track lists for records that were saved without them,
/// so the stylus can cue portions of a side and Record Detail shows both
/// sides. Runs once per record per launch; records that already have a
/// user-edited track list are never touched.
@MainActor
final class TrackListBackfill {
    static let shared = TrackListBackfill()

    private var attempted: Set<PersistentIdentifier> = []

    /// Backfill every record in the collection that has no tracks yet, plus
    /// known catalog imports that can be safely repaired without overwriting
    /// user-authored track data.
    func backfillMissingTracks(
        in records: [Record],
        lookup: ReleaseLookupService,
        modelContext: ModelContext
    ) async {
        for record in records where record.tracks.isEmpty || KnownAlbumTrackLists.canSafelyRepair(record) {
            await backfill(record: record, lookup: lookup, modelContext: modelContext)
        }
    }

    /// Fetch and persist the track list for a single record, assigning
    /// sides when the catalog didn't mark them.
    func backfill(
        record: Record,
        lookup: ReleaseLookupService,
        modelContext: ModelContext
    ) async {
        guard !attempted.contains(record.persistentModelID) else { return }
        attempted.insert(record.persistentModelID)

        if let knownTracks = KnownAlbumTrackLists.tracks(for: record),
           KnownAlbumTrackLists.canApply(knownTracks, to: record) {
            apply(knownTracks, to: record)
            try? modelContext.save()
            return
        }

        guard record.tracks.isEmpty else { return }
        guard let candidate = await candidateWithTracks(for: record, lookup: lookup) else { return }
        let tracks = ReleaseSideParser.assignSidesIfMissing(candidate.tracks)
        guard !tracks.isEmpty else { return }

        apply(tracks, to: record)
        if record.sourceReference == nil {
            record.sourceReference = candidate.id
        }
        try? modelContext.save()
    }

    private func candidateWithTracks(
        for record: Record,
        lookup: ReleaseLookupService
    ) async -> ReleaseCandidate? {
        // Prefer the release the record was created from.
        if let source = record.sourceReference {
            let stub = ReleaseCandidate(
                id: source,
                artist: record.artist,
                title: record.title,
                year: record.releaseYear,
                label: record.label,
                catalogNumber: record.catalogNumber,
                format: record.format,
                country: nil,
                barcode: record.barcode,
                coverArtURL: nil,
                tracks: []
            )
            if let detailed = try? await lookup.details(for: stub), !detailed.tracks.isEmpty {
                return detailed
            }
        }

        // Otherwise search the catalog by artist and title.
        guard let results = try? await lookup.search(text: "\(record.artist) \(record.title)"),
              let first = results.first else {
            return nil
        }
        if let detailed = try? await lookup.details(for: first), !detailed.tracks.isEmpty {
            return detailed
        }
        return first.tracks.isEmpty ? nil : first
    }

    private func apply(_ tracks: [TrackCandidate], to record: Record) {
        record.tracks = tracks.map {
            Track(side: $0.side ?? .a, trackNumber: $0.number, title: $0.title, duration: $0.seconds ?? 0)
        }
    }
}

enum KnownAlbumTrackLists {
    static func tracks(for record: Record) -> [TrackCandidate]? {
        if matches(record, artist: "Michael Jackson", title: "Thriller") {
            return sideTracks(
                a: [
                    ("Wanna Be Startin’ Somethin’", 364),
                    ("Baby Be Mine", 261),
                    ("The Girl Is Mine", 222),
                    ("Thriller", 359),
                ],
                b: [
                    ("Beat It", 259),
                    ("Billie Jean", 294),
                    ("Human Nature", 246),
                    ("P.Y.T. (Pretty Young Thing)", 239),
                    ("The Lady in My Life", 300),
                ]
            )
        }

        if matches(record, artist: "Khruangbin", title: "Con todo el mundo") {
            return sideTracks(
                a: [
                    ("Cómo me quieres", 225),
                    ("Lady and Man", 258),
                    ("María también", 190),
                    ("August 10", 265),
                    ("Cómo te quiero", 242),
                ],
                b: [
                    ("Shades of Man", 227),
                    ("Evan Finds the Third Room", 240),
                    ("A Hymn", 190),
                    ("Rules", 269),
                    ("Friday Morning", 410),
                ]
            )
        }

        return nil
    }

    static func canSafelyRepair(_ record: Record) -> Bool {
        guard let tracks = tracks(for: record) else { return false }
        return canApply(tracks, to: record)
    }

    static func canApply(_ tracks: [TrackCandidate], to record: Record) -> Bool {
        let existing = record.sequencedTracks
        guard !existing.isEmpty else { return true }

        let existingTitles = existing.map { normalized($0.title) }
        let knownTitles = tracks.map { normalized($0.title) }
        guard existingTitles == knownTitles else { return false }

        let existingSides = existing.map(\.side)
        let knownSides = tracks.map { $0.side ?? .a }
        return existingSides != knownSides
    }

    private static func sideTracks(
        a: [(String, Int)],
        b: [(String, Int)]
    ) -> [TrackCandidate] {
        let sideA = a.enumerated().map { index, item in
            TrackCandidate(side: .a, number: index + 1, title: item.0, seconds: item.1)
        }
        let sideB = b.enumerated().map { index, item in
            TrackCandidate(side: .b, number: index + 1, title: item.0, seconds: item.1)
        }
        return sideA + sideB
    }

    private static func matches(_ record: Record, artist: String, title: String) -> Bool {
        normalized(record.artist) == normalized(artist)
            && normalized(record.title) == normalized(title)
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
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
