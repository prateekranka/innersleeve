import Foundation
import SwiftData

@Model
final class PlayLogEntry {
    var playedAt: Date
    var note: String?
    var trackTitle: String?
    var trackNumber: Int?
    var trackSideRaw: String?
    var cueProgress: Double?
    var sourceRaw: String?

    var record: Record?

    init(
        playedAt: Date = .now,
        note: String? = nil,
        trackTitle: String? = nil,
        trackNumber: Int? = nil,
        trackSideRaw: String? = nil,
        cueProgress: Double? = nil,
        sourceRaw: String? = nil
    ) {
        self.playedAt = playedAt
        self.note = note
        self.trackTitle = trackTitle
        self.trackNumber = trackNumber
        self.trackSideRaw = trackSideRaw
        self.cueProgress = cueProgress
        self.sourceRaw = sourceRaw
    }
}

enum PlayLogSource: String {
    case manualLog
    case recordChange
    case stylusDrop
}
