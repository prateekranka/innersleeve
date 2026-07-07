import Foundation
import SwiftData

/// Fills in Side A/B track lists for records that were saved without them,
/// so the stylus can cue portions of a side and Record Detail shows both
/// sides. Runs once per record per launch; records that already have tracks
/// are never touched.
@MainActor
final class TrackListBackfill {
    static let shared = TrackListBackfill()

    private var attempted: Set<PersistentIdentifier> = []

    /// Backfill every record in the collection that has no tracks yet.
    func backfillMissingTracks(
        in records: [Record],
        lookup: ReleaseLookupService,
        modelContext: ModelContext
    ) async {
        for record in records where record.tracks.isEmpty {
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
        guard record.tracks.isEmpty, !attempted.contains(record.persistentModelID) else { return }
        attempted.insert(record.persistentModelID)

        guard let candidate = await candidateWithTracks(for: record, lookup: lookup) else { return }
        let tracks = ReleaseSideParser.assignSidesIfMissing(candidate.tracks)
        guard !tracks.isEmpty else { return }

        record.tracks = tracks.map {
            Track(side: $0.side ?? .a, trackNumber: $0.number, title: $0.title, duration: $0.seconds ?? 0)
        }
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
}
