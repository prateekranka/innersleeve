import Foundation
import SwiftData

/// The condition grading scale used across media and sleeves.
enum ConditionGrade: String, Codable, CaseIterable, Comparable {
    case mint
    case nearMint
    case vgPlus
    case vg
    case good
    case fair

    var shortCode: String {
        switch self {
        case .mint: return "M"
        case .nearMint: return "NM"
        case .vgPlus: return "VG+"
        case .vg: return "VG"
        case .good: return "G"
        case .fair: return "F"
        }
    }

    var displayName: String {
        switch self {
        case .mint: return "Mint"
        case .nearMint: return "Near Mint"
        case .vgPlus: return "Very Good Plus"
        case .vg: return "Very Good"
        case .good: return "Good"
        case .fair: return "Fair"
        }
    }

    private var rank: Int {
        switch self {
        case .mint: return 0
        case .nearMint: return 1
        case .vgPlus: return 2
        case .vg: return 3
        case .good: return 4
        case .fair: return 5
        }
    }

    static func < (lhs: ConditionGrade, rhs: ConditionGrade) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Physical color/appearance of the vinyl itself.
enum VinylAppearance: String, Codable, CaseIterable {
    case black
    case amber
    case smoke
    case splatter

    var displayName: String {
        switch self {
        case .black: return "Black"
        case .amber: return "Translucent Amber"
        case .smoke: return "Smoke"
        case .splatter: return "Splatter"
        }
    }
}

enum VinylStyle: String, Codable, CaseIterable {
    case black
    case translucent
    case swirl
    case marble
    case pinwheel
    case burst
    case halo
    case splatterMix
    case smoke

    var displayName: String {
        switch self {
        case .black: return "Black"
        case .translucent: return "Translucent"
        case .swirl: return "Swirl"
        case .marble: return "Marble"
        case .pinwheel: return "Pinwheel"
        case .burst: return "Burst"
        case .halo: return "Halo"
        case .splatterMix: return "Splatter"
        case .smoke: return "Smoke"
        }
    }

    static func legacyFallback(from appearance: VinylAppearance) -> VinylStyle {
        switch appearance {
        case .black: return .black
        case .amber: return .translucent
        case .smoke: return .smoke
        case .splatter: return .splatterMix
        }
    }
}

@Model
final class Record {
    var artist: String
    var title: String
    var releaseYear: Int
    var label: String
    var format: String
    var pressingDescription: String
    var barcode: String?
    var catalogNumber: String?
    var sourceReference: String?
    @Attribute(.externalStorage) var coverImageData: Data?
    var coverArtSourceURL: String?
    var coverArtScale: Double?
    var coverArtOffsetX: Double?
    var coverArtOffsetY: Double?
    var labelArtScale: Double?
    var labelArtOffsetX: Double?
    var labelArtOffsetY: Double?
    var vinylAppearance: VinylAppearance
    var vinylStyleRaw: String?
    var vinylPrimaryHex: String?
    var vinylSecondaryHex: String?
    var vinylSeed: Int?
    var artSeed: Int
    var artStyleRaw: String
    var hasCoverArt: Bool
    var conditionMedia: ConditionGrade
    var conditionSleeve: ConditionGrade
    var storageLocation: String
    var purchaseDate: Date?
    var purchasePrice: Double?
    var estimatedValue: Double?
    var lastPlayedAt: Date?
    var playCount: Int
    var notes: String
    var addedAt: Date
    var appleMusicAlbumID: String?

    @Relationship(deleteRule: .cascade, inverse: \Track.record)
    var tracks: [Track] = []

    @Relationship(deleteRule: .cascade, inverse: \PackageAttachment.record)
    var attachments: [PackageAttachment] = []

    @Relationship(deleteRule: .cascade, inverse: \PlayLogEntry.record)
    var playLog: [PlayLogEntry] = []

    init(
        artist: String,
        title: String,
        releaseYear: Int,
        label: String,
        format: String = "12\" LP, 33 RPM",
        pressingDescription: String,
        barcode: String? = nil,
        catalogNumber: String? = nil,
        sourceReference: String? = nil,
        coverImageData: Data? = nil,
        coverArtSourceURL: String? = nil,
        coverArtScale: Double = 1,
        coverArtOffsetX: Double = 0,
        coverArtOffsetY: Double = 0,
        labelArtScale: Double? = nil,
        labelArtOffsetX: Double? = nil,
        labelArtOffsetY: Double? = nil,
        vinylAppearance: VinylAppearance = .black,
        vinylStyleRaw: String? = nil,
        vinylPrimaryHex: String? = nil,
        vinylSecondaryHex: String? = nil,
        vinylSeed: Int? = nil,
        artSeed: Int,
        artStyleRaw: String = CoverArtStyle.rings.rawValue,
        hasCoverArt: Bool = true,
        conditionMedia: ConditionGrade = .nearMint,
        conditionSleeve: ConditionGrade = .vgPlus,
        storageLocation: String,
        purchaseDate: Date? = nil,
        purchasePrice: Double? = nil,
        estimatedValue: Double? = nil,
        lastPlayedAt: Date? = nil,
        playCount: Int = 0,
        notes: String = "",
        addedAt: Date = .now,
        appleMusicAlbumID: String? = nil
    ) {
        self.artist = artist
        self.title = title
        self.releaseYear = releaseYear
        self.label = label
        self.format = format
        self.pressingDescription = pressingDescription
        self.barcode = barcode
        self.catalogNumber = catalogNumber
        self.sourceReference = sourceReference
        self.coverImageData = coverImageData
        self.coverArtSourceURL = coverArtSourceURL
        self.coverArtScale = coverArtScale
        self.coverArtOffsetX = coverArtOffsetX
        self.coverArtOffsetY = coverArtOffsetY
        self.labelArtScale = labelArtScale
        self.labelArtOffsetX = labelArtOffsetX
        self.labelArtOffsetY = labelArtOffsetY
        self.vinylAppearance = vinylAppearance
        self.vinylStyleRaw = vinylStyleRaw
        self.vinylPrimaryHex = vinylPrimaryHex
        self.vinylSecondaryHex = vinylSecondaryHex
        self.vinylSeed = vinylSeed
        self.artSeed = artSeed
        self.artStyleRaw = artStyleRaw
        self.hasCoverArt = hasCoverArt
        self.conditionMedia = conditionMedia
        self.conditionSleeve = conditionSleeve
        self.storageLocation = storageLocation
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.estimatedValue = estimatedValue
        self.lastPlayedAt = lastPlayedAt
        self.playCount = playCount
        self.notes = notes
        self.addedAt = addedAt
        self.appleMusicAlbumID = appleMusicAlbumID
    }
}

extension Record {
    var artStyle: CoverArtStyle {
        CoverArtStyle(rawValue: artStyleRaw) ?? .rings
    }

    var resolvedVinylStyle: VinylStyle {
        if let vinylStyleRaw, let style = VinylStyle(rawValue: vinylStyleRaw) {
            return style
        }
        return VinylStyle.legacyFallback(from: vinylAppearance)
    }

    var resolvedVinylPrimaryHex: String {
        vinylPrimaryHex ?? Self.defaultVinylColors(for: resolvedVinylStyle, legacyAppearance: vinylAppearance).primary
    }

    var resolvedVinylSecondaryHex: String {
        vinylSecondaryHex ?? Self.defaultVinylColors(for: resolvedVinylStyle, legacyAppearance: vinylAppearance).secondary
    }

    var resolvedVinylSeed: Int {
        vinylSeed ?? artSeed
    }

    static func defaultVinylColors(
        for style: VinylStyle,
        legacyAppearance: VinylAppearance = .black
    ) -> (primary: String, secondary: String) {
        switch style {
        case .black:
            return ("#050505", "#242321")
        case .translucent:
            if legacyAppearance == .amber {
                return ("#F5B23A", "#8C540D")
            }
            return ("#F25A1D", "#F2B21A")
        case .swirl:
            return ("#10171C", "#F25A1D")
        case .marble:
            return ("#F3F2ED", "#8A8F91")
        case .pinwheel:
            return ("#050505", "#F2B21A")
        case .burst:
            return ("#F25A1D", "#10171C")
        case .halo:
            return ("#10171C", "#F2B21A")
        case .splatterMix:
            return ("#050505", "#F25A1D")
        case .smoke:
            return ("#54565A", "#10171C")
        }
    }

    var coverArtScaleValue: Double {
        coverArtScale ?? 1
    }

    var coverArtOffsetXValue: Double {
        coverArtOffsetX ?? 0
    }

    var coverArtOffsetYValue: Double {
        coverArtOffsetY ?? 0
    }

    var labelArtScaleValue: Double {
        labelArtScale ?? coverArtScale ?? 1
    }

    var labelArtOffsetXValue: Double {
        labelArtOffsetX ?? coverArtOffsetX ?? 0
    }

    var labelArtOffsetYValue: Double {
        labelArtOffsetY ?? coverArtOffsetY ?? 0
    }

    var highDefinitionCoverArtURL: URL? {
        if let sourceReference, sourceReference.hasPrefix("mb:") {
            let id = sourceReference.replacingOccurrences(of: "mb:", with: "")
            return URL(string: "https://coverartarchive.org/release/\(id)/front-1200")
        }
        if let coverArtSourceURL {
            if let upgradedURL = Self.upgradedCoverArtArchiveURL(from: coverArtSourceURL) {
                return upgradedURL
            }
            return URL(string: coverArtSourceURL)
        }
        return nil
    }

    private static func upgradedCoverArtArchiveURL(from urlString: String) -> URL? {
        guard urlString.contains("coverartarchive.org") else { return nil }
        if urlString.hasSuffix("/front-250") || urlString.hasSuffix("/front-500") {
            return URL(string: String(urlString.dropLast(3)) + "1200")
        }
        return nil
    }

    var tracksSideA: [Track] {
        tracks.filter { $0.side == .a }.sorted { $0.trackNumber < $1.trackNumber }
    }

    var tracksSideB: [Track] {
        tracks.filter { $0.side == .b }.sorted { $0.trackNumber < $1.trackNumber }
    }

    var sequencedTracks: [Track] {
        tracksSideA + tracksSideB
    }

    var sortedPlayLog: [PlayLogEntry] {
        playLog.sorted { $0.playedAt > $1.playedAt }
    }

    var conditionSummary: String {
        "\(conditionMedia.shortCode) media · \(conditionSleeve.shortCode) sleeve"
    }

    /// Records the record being played right now.
    func logPlay(note: String? = nil, at date: Date = .now) {
        let entry = PlayLogEntry(playedAt: date, note: note)
        playLog.append(entry)
        playCount += 1
        lastPlayedAt = date
    }

    func logTrackPlay(
        track: Track,
        source: PlayLogSource,
        cueProgress: Double? = nil,
        at date: Date = .now
    ) {
        let entry = PlayLogEntry(
            playedAt: date,
            trackTitle: track.title,
            trackNumber: track.trackNumber,
            trackSideRaw: track.side.rawValue,
            cueProgress: cueProgress,
            sourceRaw: source.rawValue
        )
        playLog.append(entry)
        playCount += 1
        lastPlayedAt = date
    }

    func applyRefetchedArtwork(_ data: Data, sourceURL: URL) {
        coverImageData = data
        coverArtSourceURL = sourceURL.absoluteString
        hasCoverArt = true
    }

    /// Shelf order: alphabetical by artist, then title — like a real crate.
    static func shelfOrder(_ records: [Record]) -> [Record] {
        records.sorted {
            if $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedSame {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending
        }
    }

    /// Most recently played first; never-played records go last, newest added first.
    static func recentlyPlayedOrder(_ records: [Record]) -> [Record] {
        records.sorted {
            switch ($0.lastPlayedAt, $1.lastPlayedAt) {
            case let (l?, r?): return l > r
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return $0.addedAt > $1.addedAt
            }
        }
    }
}
