import Foundation
import SwiftData

@Model
final class WishlistItem {
    var artist: String
    var title: String
    var releaseYear: Int
    var targetPressing: String
    var maxPrice: Double
    /// 1 = grail, 2 = actively hunting, 3 = keep an eye out.
    var priority: Int
    var shopLinks: [String]
    var notes: String
    var artSeed: Int
    var artStyleRaw: String
    var addedAt: Date

    init(
        artist: String,
        title: String,
        releaseYear: Int,
        targetPressing: String,
        maxPrice: Double,
        priority: Int,
        shopLinks: [String] = [],
        notes: String = "",
        artSeed: Int,
        artStyleRaw: String = CoverArtStyle.beam.rawValue,
        addedAt: Date = .now
    ) {
        self.artist = artist
        self.title = title
        self.releaseYear = releaseYear
        self.targetPressing = targetPressing
        self.maxPrice = maxPrice
        self.priority = priority
        self.shopLinks = shopLinks
        self.notes = notes
        self.artSeed = artSeed
        self.artStyleRaw = artStyleRaw
        self.addedAt = addedAt
    }
}

extension WishlistItem {
    var artStyle: CoverArtStyle {
        CoverArtStyle(rawValue: artStyleRaw) ?? .beam
    }

    var priorityLabel: String {
        switch priority {
        case 1: return "Grail"
        case 2: return "Hunting"
        default: return "Watching"
        }
    }

    var formattedMaxPrice: String {
        maxPrice.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    /// Grails first, then by price descending inside each priority band.
    static func huntOrder(_ items: [WishlistItem]) -> [WishlistItem] {
        items.sorted {
            if $0.priority != $1.priority { return $0.priority < $1.priority }
            return $0.maxPrice > $1.maxPrice
        }
    }
}
