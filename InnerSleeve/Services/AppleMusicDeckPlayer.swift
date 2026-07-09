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

    /// True while `loadAndPlay` or `play` is in-flight.
    private(set) var isLoading: Bool = false

    /// Human-readable loading phase for `statusText` differentiation.
    private var loadingMessage: String = ""

    /// The Apple Music album ID currently queued, if any.
    private(set) var currentAlbumID: String?
    private(set) var currentAlbumTitle: String?
    private(set) var currentTrackTitle: String?
    private(set) var currentTrackIndex: Int?
    private(set) var currentSide: RecordSide?

    /// Human-readable status for the amber deck display or control.
    var statusText: String {
        if !isAuthorized {
            return authorizationUndetermined ? "Connect Apple Music" : "Apple Music unavailable"
        }
        if let error = errorMessage {
            return error
        }
        if isLoading {
            return loadingMessage
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

    /// Last catalog album loaded with its tracks, so re-dropping the stylus
    /// on the same record re-queues instantly instead of re-fetching.
    private var loadedAlbumID: String?
    private var loadedAlbum: MusicKit.Album?
    private var playbackRequests = PlaybackRequestGate()
    @ObservationIgnored private var playerPlayTask: Task<Void, Error>?

    // MARK: Public API

    /// Request Media & Apple Music authorization if not yet determined.
    func requestAuthorization() async {
        authorizationStatus = MusicAuthorization.currentStatus
        guard authorizationStatus == .notDetermined else { return }
        let status = await MusicAuthorization.request()
        authorizationStatus = status
    }

    /// Load and play one physical side, using a side-local starting index.
    func loadAndPlay(
        record: Record,
        side: RecordSide,
        startingAt sideTrackIndex: Int = 0,
        seekToSeconds: Double = 0,
        modelContext: ModelContext
    ) async {
        let requestGeneration = beginPlaybackRequest()
        errorMessage = nil
        isLoading = true
        loadingMessage = "Finding on Apple Music…"

        defer {
            if isCurrentRequest(requestGeneration) {
                isLoading = false
            }
        }

        guard await ensureAuthorization() else {
            if isCurrentRequest(requestGeneration) {
                errorMessage = "Apple Music unavailable"
            }
            return
        }
        guard isCurrentRequest(requestGeneration) else { return }

        let recordID = record.persistentModelID
        let playableTracks = record.tracks(on: side)
        let catalogTrackRange = record.catalogTrackRange(for: side)
        let clampedTrackIndex = AppleMusicDeckPlayer.clampedTrackIndex(
            sideTrackIndex,
            trackCount: playableTracks.count
        )
        let track = playableTracks[safe: clampedTrackIndex]

        if let cachedID = albumIDCache[recordID] ?? record.appleMusicAlbumID {
            loadingMessage = "Loading album…"
            await playAlbum(
                albumID: cachedID,
                side: side,
                startingAt: clampedTrackIndex,
                seekToSeconds: seekToSeconds,
                albumTitle: record.title,
                trackTitle: track?.title,
                catalogTrackRange: catalogTrackRange,
                localSideTrackTitles: playableTracks.map(\.title),
                requestGeneration: requestGeneration
            )
            return
        }

        let albumID: String
        do {
            guard let foundAlbumID = try await searchAlbum(artist: record.artist, title: record.title) else {
                if isCurrentRequest(requestGeneration) {
                    errorMessage = "Album not found"
                }
                return
            }
            albumID = foundAlbumID
        } catch {
            if isCurrentRequest(requestGeneration) {
                errorMessage = AppleMusicDeckPlayer.lookupFailureMessage(for: error)
            }
            return
        }
        guard isCurrentRequest(requestGeneration) else { return }

        record.appleMusicAlbumID = albumID
        albumIDCache[recordID] = albumID
        try? modelContext.save()

        loadingMessage = "Loading album…"
        await playAlbum(
            albumID: albumID,
            side: side,
            startingAt: clampedTrackIndex,
            seekToSeconds: seekToSeconds,
            albumTitle: record.title,
            trackTitle: track?.title,
            catalogTrackRange: catalogTrackRange,
            localSideTrackTitles: playableTracks.map(\.title),
            requestGeneration: requestGeneration
        )
    }

    /// Play one physical side, starting at a side-local track index.
    /// The supplied range is the side's location in the catalog album.
    func play(
        albumID: String,
        side: RecordSide,
        startingAt sideTrackIndex: Int = 0,
        seekToSeconds: Double = 0,
        albumTitle: String? = nil,
        trackTitle: String? = nil,
        catalogTrackRange: Range<Int>,
        sideTrackTitles: [String]
    ) async {
        let requestGeneration = beginPlaybackRequest()
        await playAlbum(
            albumID: albumID,
            side: side,
            startingAt: sideTrackIndex,
            seekToSeconds: seekToSeconds,
            albumTitle: albumTitle,
            trackTitle: trackTitle,
            catalogTrackRange: catalogTrackRange,
            localSideTrackTitles: sideTrackTitles,
            requestGeneration: requestGeneration
        )
    }

    private func playAlbum(
        albumID: String,
        side: RecordSide,
        startingAt sideTrackIndex: Int,
        seekToSeconds: Double,
        albumTitle: String?,
        trackTitle: String?,
        catalogTrackRange: Range<Int>,
        localSideTrackTitles: [String],
        requestGeneration: Int
    ) async {
        guard isCurrentRequest(requestGeneration) else { return }
        errorMessage = nil
        isLoading = true
        loadingMessage = "Loading album…"

        defer {
            if isCurrentRequest(requestGeneration) {
                isLoading = false
            }
        }

        do {
            let albumWithTracks: MusicKit.Album
            if let loadedAlbum, loadedAlbumID == albumID {
                albumWithTracks = loadedAlbum
            } else {
                var request = MusicCatalogResourceRequest<MusicKit.Album>(matching: \.id, equalTo: MusicItemID(albumID))
                request.limit = 1
                let response = try await request.response()
                guard isCurrentRequest(requestGeneration) else { return }

                guard let album = response.items.first else {
                    errorMessage = "Album unavailable"
                    return
                }

                albumWithTracks = try await album.with(.tracks)
                guard isCurrentRequest(requestGeneration) else { return }
                loadedAlbum = albumWithTracks
                loadedAlbumID = albumID
            }

            let tracks = Array(albumWithTracks.tracks ?? MusicItemCollection<MusicKit.Track>([]))
            guard !tracks.isEmpty else {
                errorMessage = "Album has no tracks"
                isPlaying = false
                return
            }

            let sideRange = AppleMusicDeckPlayer.resolvedCatalogTrackRange(
                suggestedRange: catalogTrackRange,
                localSideTrackTitles: localSideTrackTitles,
                appleMusicTrackTitles: tracks.map(\.title)
            )
            guard !sideRange.isEmpty else {
                errorMessage = "Record side unavailable"
                isPlaying = false
                return
            }

            let catalogTrackIndex = AppleMusicDeckPlayer.mappedCatalogTrackIndex(
                localTrackTitle: trackTitle,
                requestedSideIndex: sideTrackIndex,
                catalogTrackRange: sideRange,
                appleMusicTrackTitles: tracks.map(\.title)
            )

            let sideTracks = Array(tracks[sideRange])
            let startTrack = tracks[catalogTrackIndex]
            guard isCurrentRequest(requestGeneration) else { return }
            player.queue = ApplicationMusicPlayer.Queue(for: sideTracks, startingAt: startTrack)

            let playTask = Task { @MainActor in
                try await player.play()
            }
            playerPlayTask = playTask
            try await playTask.value

            switch playbackRequests.completionDisposition(for: requestGeneration) {
            case .publish:
                playerPlayTask = nil
            case .stopPlayer:
                playerPlayTask = nil
                player.stop()
                return
            case .discard:
                return
            }
            guard !Task.isCancelled else {
                if playbackRequests.completionDisposition(for: requestGeneration) == .stopPlayer {
                    player.stop()
                }
                return
            }
            if seekToSeconds > 1 {
                player.playbackTime = seekToSeconds
            }
            currentAlbumID = albumID
            currentAlbumTitle = albumTitle ?? albumWithTracks.title
            currentTrackTitle = trackTitle ?? startTrack.title
            currentTrackIndex = catalogTrackIndex - sideRange.lowerBound
            currentSide = side
            isPlaying = true
        } catch {
            switch playbackRequests.completionDisposition(for: requestGeneration) {
            case .publish:
                playerPlayTask = nil
                errorMessage = "Playback failed"
                isPlaying = false
            case .stopPlayer:
                playerPlayTask = nil
                player.stop()
            case .discard:
                break
            }
        }
    }

    /// Stops playback and resets state.
    func stop() {
        playbackRequests.invalidate()
        playerPlayTask?.cancel()
        playerPlayTask = nil
        player.stop()
        isPlaying = false
        isLoading = false
        currentAlbumID = nil
        currentAlbumTitle = nil
        currentTrackTitle = nil
        currentTrackIndex = nil
        currentSide = nil
    }

    private func beginPlaybackRequest() -> Int {
        playerPlayTask?.cancel()
        playerPlayTask = nil
        player.stop()
        isPlaying = false
        return playbackRequests.begin()
    }

    private func isCurrentRequest(_ generation: Int) -> Bool {
        playbackRequests.isCurrent(generation) && !Task.isCancelled
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

    /// Seconds into the cued track (per `stylusCueTrackIndex`) that the given
    /// stylus progress lands on, so playback starts from that portion of the
    /// record rather than the top of the track.
    ///
    /// Returns 0 when durations are unknown, and snaps drops within the
    /// first two seconds of a track to a clean track start.
    nonisolated static func stylusCueSeekSeconds(progress: Double, trackDurations: [Int]) -> Double {
        guard !trackDurations.isEmpty, trackDurations.allSatisfy({ $0 > 0 }) else { return 0 }

        let clamped = min(max(progress, 0), 1)
        let totalDuration = trackDurations.reduce(0, +)
        let targetTime = clamped * Double(totalDuration)
        let index = stylusCueTrackIndex(progress: progress, trackDurations: trackDurations)
        let elapsedBefore = trackDurations.prefix(index).reduce(0, +)

        let offset = min(
            max(targetTime - Double(elapsedBefore), 0),
            Double(trackDurations[index] - 1)
        )
        return offset < 2 ? 0 : offset
    }

    nonisolated static func deckTickerText(
        albumTitle: String?,
        trackTitle: String?,
        side: RecordSide? = nil
    ) -> String {
        let album = albumTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let track = trackTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let recordText: String
        switch (album.isEmpty, track.isEmpty) {
        case (false, false): recordText = "\(album)  •  \(track)"
        case (false, true): recordText = album
        case (true, false): recordText = track
        case (true, true): recordText = "No record on deck"
        }

        guard let side else { return recordText }
        return "SIDE \(side.rawValue)  •  \(recordText)"
    }

    nonisolated static func clampedTrackIndex(_ index: Int, trackCount: Int) -> Int {
        guard trackCount > 0 else { return 0 }
        return min(max(index, 0), trackCount - 1)
    }

    nonisolated static func mappedCatalogTrackIndex(
        localTrackTitle: String?,
        requestedIndex: Int,
        appleMusicTrackTitles: [String]
    ) -> Int {
        mappedCatalogTrackIndex(
            localTrackTitle: localTrackTitle,
            requestedSideIndex: requestedIndex,
            catalogTrackRange: 0..<appleMusicTrackTitles.count,
            appleMusicTrackTitles: appleMusicTrackTitles
        )
    }

    /// Maps a side-local request into the catalog album while limiting title
    /// matching and fallback clamping to that side's catalog range.
    nonisolated static func mappedCatalogTrackIndex(
        localTrackTitle: String?,
        requestedSideIndex: Int,
        catalogTrackRange: Range<Int>,
        appleMusicTrackTitles: [String]
    ) -> Int {
        let range = clampedCatalogTrackRange(
            catalogTrackRange,
            trackCount: appleMusicTrackTitles.count
        )
        guard !range.isEmpty else { return 0 }

        let fallback = range.lowerBound + clampedTrackIndex(
            requestedSideIndex,
            trackCount: range.count
        )
        guard let localTrackTitle else { return fallback }
        let normalizedLocal = normalizedTrackTitle(localTrackTitle)
        guard !normalizedLocal.isEmpty else { return fallback }

        if let exactMatch = appleMusicTrackTitles[range].firstIndex(where: {
            normalizedTrackTitle($0) == normalizedLocal
        }) {
            return exactMatch
        }

        return fallback
    }

    nonisolated static func clampedCatalogTrackRange(
        _ range: Range<Int>,
        trackCount: Int
    ) -> Range<Int> {
        let count = max(trackCount, 0)
        let lowerBound = min(max(range.lowerBound, 0), count)
        let upperBound = min(max(range.upperBound, 0), count)
        return lowerBound..<max(lowerBound, upperBound)
    }

    /// Reconciles local side metadata with the selected Apple Music edition.
    /// Ordered title anchors shift or expand the nominal local-count range when
    /// the catalog edition contains an omitted track or an extra cut.
    nonisolated static func resolvedCatalogTrackRange(
        suggestedRange: Range<Int>,
        localSideTrackTitles: [String],
        appleMusicTrackTitles: [String]
    ) -> Range<Int> {
        let fallback = clampedCatalogTrackRange(
            suggestedRange,
            trackCount: appleMusicTrackTitles.count
        )
        guard !localSideTrackTitles.isEmpty, !appleMusicTrackTitles.isEmpty else {
            return fallback
        }

        let normalizedCatalog = appleMusicTrackTitles.map(normalizedTrackTitle)
        let normalizedLocal = localSideTrackTitles.map(normalizedTrackTitle)
        var anchors: [(local: Int, catalog: Int)] = []
        var searchStart = 0

        for (localIndex, title) in normalizedLocal.enumerated() where !title.isEmpty {
            let candidates = normalizedCatalog.indices.filter {
                $0 >= searchStart && normalizedCatalog[$0] == title
            }
            guard !candidates.isEmpty else { continue }

            let expectedIndex = fallback.lowerBound + localIndex
            let catalogIndex: Int
            if anchors.isEmpty {
                catalogIndex = candidates.min {
                    abs($0 - expectedIndex) < abs($1 - expectedIndex)
                } ?? candidates[0]
            } else {
                catalogIndex = candidates[0]
            }

            anchors.append((local: localIndex, catalog: catalogIndex))
            searchStart = catalogIndex + 1
        }

        guard let first = anchors.first, let last = anchors.last else {
            return fallback
        }

        let inferredLower = max(first.catalog - first.local, 0)
        let remainingLocalTracks = normalizedLocal.count - last.local - 1
        let inferredUpper = last.catalog + remainingLocalTracks + 1
        let resolved = clampedCatalogTrackRange(
            inferredLower..<inferredUpper,
            trackCount: appleMusicTrackTitles.count
        )
        return resolved.isEmpty ? fallback : resolved
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

    private nonisolated static func normalizedTrackTitle(_ value: String) -> String {
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

/// Monotonic invalidation for async catalog/play requests. A stopped or
/// superseded request can finish its await, but it can no longer mutate the
/// queue or publish playback state.
struct PlaybackRequestGate {
    enum CompletionDisposition: Equatable {
        case publish
        case discard
        case stopPlayer
    }

    private(set) var generation = 0
    private(set) var activeGeneration: Int?

    mutating func begin() -> Int {
        generation &+= 1
        activeGeneration = generation
        return generation
    }

    mutating func invalidate() {
        generation &+= 1
        activeGeneration = nil
    }

    func isCurrent(_ candidate: Int) -> Bool {
        candidate == activeGeneration
    }

    func completionDisposition(for candidate: Int) -> CompletionDisposition {
        if candidate == activeGeneration {
            return .publish
        }
        return activeGeneration == nil ? .stopPlayer : .discard
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
