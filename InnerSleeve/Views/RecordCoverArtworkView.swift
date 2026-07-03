import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RecordCoverArtworkView: View {
    var record: Record

    var body: some View {
        ZStack {
            #if canImport(UIKit)
            if let data = record.coverImageData {
                CoverArtworkImageView(imageData: data)
            } else {
                procedural
            }
            #else
            procedural
            #endif
        }
    }

    private var procedural: some View {
        CoverArtView(
            seed: record.artSeed,
            style: record.hasCoverArt ? record.artStyle : .missing,
            initials: record.artist.artInitials,
            titleText: record.hasCoverArt ? "" : record.title
        )
    }
}
