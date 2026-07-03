import Foundation
import SwiftData

/// The kinds of physical objects that live inside a record's package.
enum AttachmentKind: String, Codable, CaseIterable {
    case lyricInsert
    case poster
    case obiStrip
    case receipt
    case hypeSticker
    case booklet
    case signedItem
    case innerSleeve

    var displayName: String {
        switch self {
        case .lyricInsert: return "Lyric Insert"
        case .poster: return "Poster"
        case .obiStrip: return "Obi Strip"
        case .receipt: return "Receipt"
        case .hypeSticker: return "Hype Sticker"
        case .booklet: return "Booklet"
        case .signedItem: return "Signed Item"
        case .innerSleeve: return "Inner Sleeve"
        }
    }

    var systemImage: String {
        switch self {
        case .lyricInsert: return "doc.text"
        case .poster: return "photo"
        case .obiStrip: return "bookmark"
        case .receipt: return "receipt"
        case .hypeSticker: return "seal"
        case .booklet: return "book.closed"
        case .signedItem: return "signature"
        case .innerSleeve: return "square"
        }
    }
}

@Model
final class PackageAttachment {
    var kind: AttachmentKind
    var title: String
    var condition: ConditionGrade
    var notes: String
    /// Seed used to jitter its placement on the archive table.
    var placementSeed: Int

    var record: Record?

    init(
        kind: AttachmentKind,
        title: String,
        condition: ConditionGrade = .nearMint,
        notes: String = "",
        placementSeed: Int = Int.random(in: 0...9_999)
    ) {
        self.kind = kind
        self.title = title
        self.condition = condition
        self.notes = notes
        self.placementSeed = placementSeed
    }
}
