import Foundation
import MusicKit
import Observation
import SwiftData

/// Manages Apple Music playback for the turntable deck.
///
/// Owned by `TurntableModeView` as `@State`. Handles authorization,
/// catalog search, album-ID caching, and queue-driven playback through
/// `ApplicationMusicPlayer.shared`.
///
/// The player keeps album plays sequential: no track picker, arbitrary
/// queue editing, or next/previous controls are exposed.
@MainActor
@Observable
final class AppleMusicDeckPlayer {

    // MARK: Authorization

    var authorizationStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus

    /// User has granted permission.
    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    /// True until the user has responded to the permission dialog at least once.
    var authorizationUndetermined: Bool {
        authorizationStatus == .notDetermined
    }

    // MARK: Playback state

    /// Whether the shared application player is currently playing.
    var isPlaying: Bool = false

    /// The Apple Music album ID currently queued, if any.
    private(set) var currentAlbumID: String?
    private(set) var currentAlbumTitle: String?
    private(set) var currentTrackTitle: String?
    private(set) var currentTrackIndex: Int?

    /// Human-readable status for the amber deck display or control.
    var statusText: String {
        if !isAuthorized {
            return authorizationUndetermined ? "Connect Apple Music" : "Apple Music unavailable"
        }
        if let error = errorMessage {
            return error
        }
        if isPlaying {
            return "Now playing"
        }
        return "Ready"
    }

    /// Non-nil when a recoverable error occurred during search or playback.
    private(set) var errorMessage: String?

    // MARK: Privates

    private let player = ApplicationMusicPlayer.shared
    private var albumIDCache: [PersistentIdentifier: String] = [:]

    // MARK: Public API

    /// Request Media & Apple Music authorization if not yet determined.
    func requestAuthorization() async {
        authorizationStatus = MusicAuthorization.currentStatus
        guard authorizationStatus == .notDetermined else { return }
        let status = await MusicAuthorization.request()
        authorizationStatus = status
    }

    /// Load and play the given record from the requested track.
    ///
    /// If `appleMusicAlbumID` is already cached on the record, playback
    /// starts immediately. Otherwise the catalog is searched and the
    /// result is persisted before playing.
    func loadAndPlay(record: Record, startingAt trackIndex: Int = 0, modelContext: ModelContext) async {
        errorMessage = nil

        guard await ensureAuthorization() else {
            errorMessage = "Apple Music unavailable"
            return
        }

        let recordID = record.persistentModelID

        // Check in-memory cache first, then the persisted property.
        if let cachedID = albumIDCache[recordID] ?? record.appleMusicAlbumID {
            let clampedTrackIndex = AppleMusicDeckPlayer.clampedTrackIndex(
                trackIndex,
                trackCount: record.sequencedTracks.count
            )
            let track = record.sequencedTracks[safe: clampedTrackIndex]
            await play(
                albumID: cachedID,
                startingAt: clampedTrackIndex,
                albumTitle: record.title,
                trackTitle: track?.title
            )
            return
        }

        let albumID: String
        do {
            guard let foundAlbumID = try await searchAlbum(artist: record.artist, title: record.title) else {
                errorMessage = "Album not found"
                return
            }
            albumID = foundAlbumID
        } catch {
            errorMessage = AppleMusicDeckPlayer.lookupFailureMessage(for: error)
            return
        }

        // Persist the match.
        record.appleMusicAlbumID = albumID
        albumIDCache[recordID] = albumID
        try? modelContext.save()

        let clampedTrackIndex = AppleMusicDeckPlayer.clampedTrackIndex(
            trackIndex,
            trackCount: record.sequencedTracks.count
        )
        let track = record.sequencedTracks[safe: clampedTrackIndex]
        await play(
            albumID: albumID,
            startingAt: clampedTrackIndex,
            albumTitle: record.title,
            trackTitle: track?.title
        )
    }

    /// Play the album identified by `albumID`, optionally starting at a
    /// different track index (0-based, from the catalog track list order).
    func play(
        albumID: String,
        startingAt trackIndex: Int = 0,
        albumTitle: String? = nil,
        trackTitle: String? = nil
    ) async {
        errorMessage = nil

        do {
            var request = MusicCatalogResourceRequest<MusicKit.Album>(matching: \.id, equalTo: MusicItemID(albumID))
            request.limit = 1
            let response = try await request.response()

            guard let album = response.items.first else {
                errorMessage = "Album unavailable"
                return
            }

            let albumWithTracks = try await album.with(.tracks)
            let tracks = Array(albumWithTracks.tracks ?? MusicItemCollection<MusicKit.Track>([]))
            guard !tracks.isEmpty else {
                errorMessage = "Album has no tracks"
                isPlaying = false
                return
            }
            let clampedIndex = min(max(trackIndex, 0), max(tracks.count - 1, 0))

            let startTrack = tracks[clampedIndex]
            player.queue = ApplicationMusicPlayer.Queue(album: albumWithTracks, startingAt: startTrack)

            try await player.play()
            currentAlbumID = albumID
            currentAlbumTitle = albumTitle ?? album.title
            currentTrackTitle = trackTitle ?? startTrack.title
            currentTrackIndex = clampedIndex
            isPlaying = true
        } catch {
            errorMessage = "Playback failed"
            isPlaying = false
        }
    }

    /// Stops playback and resets state.
    func stop() {
        player.stop()
        isPlaying = false
        currentAlbumID = nil
        currentAlbumTitle = nil
        currentTrackTitle = nil
        currentTrackIndex = nil
    }

    // MARK: Catalog search

    private func ensureAuthorization() async -> Bool {
        authorizationStatus = MusicAuthorization.currentStatus
        if authorizationStatus == .notDetermined {
            authorizationStatus = await MusicAuthorization.request()
        }
        return authorizationStatus == .authorized
    }

    /// Search the Apple Music catalog for an album matching the given artist
    /// and title. Returns the catalog album ID string, or nil if nothing matched.
    func searchAlbum(artist: String, title: String) async throws -> String? {
        for term in AppleMusicSearchTuning.catalogSearchTerms(artist: artist, title: title) {
            var request = MusicCatalogSearchRequest(term: term, types: [MusicKit.Album.self])
            request.limit = 10
            let response = try await request.response()
            if let best = AppleMusicDeckPlayer.bestMatch(
                albums: response.albums,
                artist: artist,
                title: title
            ) {
                return best.id.rawValue
            }
        }

        return nil
    }

    // MARK: Stylus cue mapping

    /// Maps a stylus cue progress value (0 at outer edge, 1 at spindle) to a
    /// 0-based track index for a record with the given number of tracks.
    ///
    /// Pure function; safe to call from tests and previews.
    nonisolated static func stylusCueTrackIndex(progress: Double, trackCount: Int) -> Int {
        guard trackCount > 0 else { return 0 }
        let clamped = min(max(progress, 0), 1)
        let index = Int((clamped * Double(trackCount - 1)).rounded())
        return min(max(index, 0), trackCount - 1)
    }

    nonisolated static func stylusCueTrackIndex(progress: Double, trackDurations: [Int]) -> Int {
        guard !trackDurations.isEmpty else { return 0 }
        guard trackDurations.allSatisfy({ $0 > 0 }) else {
            return stylusCueTrackIndex(progress: progress, trackCount: trackDurations.count)
        }

        let clamped = min(max(progress, 0), 1)
        let totalDuration = trackDurations.reduce(0, +)
        let targetTime = clamped * Double(totalDuration)
        var elapsed = 0

        for (index, duration) in trackDurations.enumerated() {
            elapsed += duration
            if targetTime <= Double(elapsed) {
                return index
            }
        }

        return trackDurations.count - 1
    }

    nonisolated static func deckTickerText(albumTitle: String?, trackTitle: String?) -> String {
        let album = albumTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let track = trackTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        switch (album.isEmpty, track.isEmpty) {
        case (false, false): return "\(album)  •  \(track)"
        case (false, true): return album
        case (true, false): return track
        case (true, true): return "No record on deck"
        }
    }

    nonisolated static func clampedTrackIndex(_ index: Int, trackCount: Int) -> Int {
        guard trackCount > 0 else { return 0 }
        return min(max(index, 0), trackCount - 1)
    }

    /// Picks the best album match for a record's artist and title.
    ///
    /// Uses a simple case-insensitive word-overlap score on artist and title.
    /// Higher scores mean better matches. Ties are broken by earlier release
    /// date so canonical editions win.
    ///
    /// Pure function; safe to call from tests and previews.
    static func bestMatch(
        albums: MusicItemCollection<MusicKit.Album>,
        artist: String,
        title: String
    ) -> MusicKit.Album? {
        let artistWords = AppleMusicSearchTuning.normalizedWords(in: artist)
        let titleWords = AppleMusicSearchTuning.normalizedWords(in: title)
        let titleThreshold = AppleMusicSearchTuning.titleOverlapThreshold(for: titleWords)

        let scored = albums.map { album -> (album: MusicKit.Album, score: Int, titleOverlap: Int) in
            let aWords = AppleMusicSearchTuning.normalizedWords(in: album.artistName)
            let tWords = AppleMusicSearchTuning.normalizedWords(in: album.title)
            let artistOverlap = artistWords.intersection(aWords).count
            let titleOverlap = titleWords.intersection(tWords).count
            // Title match is weighted higher than artist match.
            return (album, titleOverlap * 3 + artistOverlap, titleOverlap)
        }

        guard let best = scored.max(by: { a, b in
            if a.score != b.score { return a.score < b.score }
            // Tiebreak: prefer earlier release date.
            let aDate = a.album.releaseDate ?? .distantFuture
            let bDate = b.album.releaseDate ?? .distantFuture
            return aDate > bDate
        }), best.score > 0, best.titleOverlap >= titleThreshold else {
            return nil
        }

        return best.album
    }

    private static func lookupFailureMessage(for error: Error) -> String {
        let description = String(describing: error).lowercased()
        if description.contains("token")
            || description.contains("permission")
            || description.contains("unauthorized")
            || description.contains("entitlement")
            || description.contains("account") {
            return "Apple Music setup needed"
        }
        return "Apple Music lookup failed"
    }
}

// MARK: - Safe array subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

enum AppleMusicSearchTuning {
    nonisolated static func catalogSearchTerms(artist: String, title: String) -> [String] {
        let cleanArtist = searchPhrase(artist)
        let cleanTitle = searchPhrase(title)
        return [
            "\(cleanArtist) \(cleanTitle)",
            "\(cleanTitle) \(cleanArtist)",
            cleanTitle,
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .reduce(into: []) { terms, term in
            if !terms.contains(term) {
                terms.append(term)
            }
        }
    }

    nonisolated static func normalizedWords(in text: String) -> Set<String> {
        let folded = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "&", with: " and ")
        let words = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !stopWords.contains($0) }
        return Set(words)
    }

    nonisolated static func titleOverlapThreshold(for titleWords: Set<String>) -> Int {
        max(1, min(2, titleWords.count))
    }

    private nonisolated static func searchPhrase(_ text: String) -> String {
        let folded = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "&", with: " and ")
        let words = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !editionWords.contains($0) }
        return words.joined(separator: " ")
    }

    private static let stopWords: Set<String> = [
        "a", "an", "and", "the", "of", "to", "for", "in", "on",
    ]

    private static let editionWords: Set<String> = [
        "anniversary", "bonus", "deluxe", "edition", "expanded", "lp",
        "mono", "remaster", "remastered", "stereo", "version", "vinyl",
    ]
}
