import Foundation
import SwiftData

/// In-memory model containers for #Preview variants.
@MainActor
enum PreviewContainers {

    static var full: ModelContainer {
        make { FixtureData.seedFull(into: $0) }
    }

    static var empty: ModelContainer {
        make { _ in }
    }

    static var longTitles: ModelContainer {
        make { context in
            let records = FixtureData.makeRecords()
            if let longOne = records.first(where: { $0.title.count > 40 }) {
                context.insert(longOne)
            }
            let extra = Record(
                artist: "The International Brotherhood of Extremely Patient Listeners",
                title: "An Exhaustive and Unabridged Catalogue of Sounds We Have Loved, Volume One of Four",
                releaseYear: 1977,
                label: "Longform Recording Concern",
                pressingDescription: "1977 original, quadruple gatefold with 40-page libretto",
                artSeed: 301,
                artStyleRaw: CoverArtStyle.wave.rawValue,
                storageLocation: "Oversize Shelf · Slot 01"
            )
            extra.tracks = [
                Track(side: .a, trackNumber: 1, title: "Overture for Tape Hiss, Room Tone, and the Sound of a Distant Kettle Slowly Coming to a Boil", duration: 754),
                Track(side: .b, trackNumber: 1, title: "Intermission (The Long Walk to the Turntable and Back Again)", duration: 812),
            ]
            context.insert(extra)
        }
    }

    static var missingCover: ModelContainer {
        make { context in
            for record in FixtureData.makeRecords() where !record.hasCoverArt {
                context.insert(record)
            }
        }
    }

    static var denseArchive: ModelContainer {
        make { context in
            if let dense = FixtureData.makeRecords().max(by: { $0.attachments.count < $1.attachments.count }) {
                context.insert(dense)
            }
        }
    }

    static var wishlistHeavy: ModelContainer {
        make { FixtureData.seedWishlistHeavy(into: $0) }
    }

    // MARK: Factory

    private static func make(_ seed: (ModelContext) -> Void) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(
                for: Record.self, Track.self, PackageAttachment.self, WishlistItem.self, PlayLogEntry.self,
                configurations: configuration
            )
            seed(container.mainContext)
            try container.mainContext.save()
            return container
        } catch {
            fatalError("Failed to build preview container: \(error)")
        }
    }
}
