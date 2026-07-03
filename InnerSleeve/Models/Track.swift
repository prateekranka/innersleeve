import Foundation
import SwiftData

enum RecordSide: String, Codable, CaseIterable {
    case a = "A"
    case b = "B"

    var displayName: String { "Side \(rawValue)" }
}

@Model
final class Track {
    var side: RecordSide
    var trackNumber: Int
    var title: String
    /// Duration in whole seconds.
    var duration: Int
    var favorite: Bool
    var notes: String

    var record: Record?

    init(
        side: RecordSide,
        trackNumber: Int,
        title: String,
        duration: Int,
        favorite: Bool = false,
        notes: String = ""
    ) {
        self.side = side
        self.trackNumber = trackNumber
        self.title = title
        self.duration = duration
        self.favorite = favorite
        self.notes = notes
    }
}

extension Track {
    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
