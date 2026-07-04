import SwiftData
import SwiftUI

struct AddRecordFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var route: Route = .chooser
    @State private var errorText: String?
    var onSaved: (Record) -> Void

    enum Route {
        case chooser
        case scanner
        case search
        case form(RecordDraft)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch route {
                case .chooser:
                    chooser
                case .scanner:
                    BarcodeScannerView { barcode in
                        Task { await lookupBarcode(barcode) }
                    }
                case .search:
                    CatalogSearchView { candidate in
                        route = .form(RecordDraft(candidate: candidate))
                    }
                case let .form(draft):
                    RecordFormView(draft: draft, title: "Add record", saveTitle: "Add") { draft in
                        save(draft)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var chooser: some View {
        ZStack {
            Palette.stageGrey.ignoresSafeArea()
            VStack(spacing: 16) {
                Button {
                    route = .scanner
                } label: {
                    Label("Scan barcode", systemImage: "barcode.viewfinder")
                }
                .buttonStyle(.glassProminent)
                .tint(Palette.orangeAccent)

                Button {
                    route = .search
                } label: {
                    Label("Search catalog", systemImage: "magnifyingglass")
                }
                .buttonStyle(.glass)

                Button {
                    route = .form(RecordDraft())
                } label: {
                    Label("Manual entry", systemImage: "square.and.pencil")
                }
                .buttonStyle(.glass)

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.orangeAccent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
            }
            .tint(Palette.inkOnStage)
        }
        .navigationTitle("Add record")
    }

    private func lookupBarcode(_ barcode: String) async {
        do {
            let candidates = try await settings.makeLookupService().search(barcode: barcode)
            if let first = candidates.first {
                let detailed = (try? await settings.makeLookupService().details(for: first)) ?? first
                route = .form(RecordDraft(candidate: detailed))
            } else {
                var draft = RecordDraft()
                draft.barcode = barcode
                route = .form(draft)
            }
        } catch {
            var draft = RecordDraft()
            draft.barcode = barcode
            errorText = (error as? LocalizedError)?.errorDescription ?? "Lookup failed. Manual entry is still available."
            route = .form(draft)
        }
    }

    private func save(_ draft: RecordDraft) {
        let record = Record(draft: draft)
        modelContext.insert(record)
        onSaved(record)
        if draft.coverImageData == nil {
            Task { await loadCover(for: record, url: draft.coverArtURL) }
        }
        dismiss()
    }

    @MainActor
    private func loadCover(for record: Record, url: URL?) async {
        guard let url else { return }
        if let data = try? await CoverArtLoader().loadData(from: url) {
            record.applyRefetchedArtwork(data, sourceURL: url)
            try? modelContext.save()
        }
    }
}

extension Record {
    convenience init(draft: RecordDraft) {
        self.init(
            artist: draft.artist,
            title: draft.title,
            releaseYear: draft.releaseYear,
            label: draft.label,
            format: draft.format,
            pressingDescription: draft.pressingDescription.isEmpty ? draft.format : draft.pressingDescription,
            barcode: draft.barcode.isEmpty ? nil : draft.barcode,
            catalogNumber: draft.catalogNumber.isEmpty ? nil : draft.catalogNumber,
            sourceReference: draft.sourceReference,
            coverImageData: draft.coverImageData,
            coverArtSourceURL: draft.coverArtURL?.absoluteString,
            coverArtScale: draft.coverArtScale,
            coverArtOffsetX: draft.coverArtOffsetX,
            coverArtOffsetY: draft.coverArtOffsetY,
            labelArtScale: draft.labelArtScale,
            labelArtOffsetX: draft.labelArtOffsetX,
            labelArtOffsetY: draft.labelArtOffsetY,
            vinylAppearance: draft.vinylAppearance,
            vinylStyleRaw: draft.vinylStyleRaw,
            vinylPrimaryHex: draft.vinylPrimaryHex,
            vinylSecondaryHex: draft.vinylSecondaryHex,
            vinylSeed: draft.vinylSeed,
            artSeed: draft.artSeed,
            artStyleRaw: CoverArtStyle.rings.rawValue,
            conditionMedia: draft.conditionMedia,
            conditionSleeve: draft.conditionSleeve,
            storageLocation: draft.storageLocation,
            notes: draft.notes
        )
        tracks = draft.tracks
            .filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { Track(side: $0.side, trackNumber: $0.number, title: $0.title, duration: $0.duration) }
    }

    func apply(_ draft: RecordDraft) {
        // A different artist/title means any previous Apple Music match is
        // for the wrong album; drop it so the deck re-searches on next play.
        if draft.artist != artist || draft.title != title {
            appleMusicAlbumID = nil
        }
        artist = draft.artist
        title = draft.title
        releaseYear = draft.releaseYear
        label = draft.label
        format = draft.format
        pressingDescription = draft.pressingDescription
        barcode = draft.barcode.isEmpty ? nil : draft.barcode
        catalogNumber = draft.catalogNumber.isEmpty ? nil : draft.catalogNumber
        sourceReference = draft.sourceReference
        coverImageData = draft.coverImageData ?? coverImageData
        coverArtSourceURL = draft.coverArtURL?.absoluteString ?? coverArtSourceURL
        coverArtScale = draft.coverArtScale
        coverArtOffsetX = draft.coverArtOffsetX
        coverArtOffsetY = draft.coverArtOffsetY
        labelArtScale = draft.labelArtScale
        labelArtOffsetX = draft.labelArtOffsetX
        labelArtOffsetY = draft.labelArtOffsetY
        vinylAppearance = draft.vinylAppearance
        vinylStyleRaw = draft.vinylStyleRaw
        vinylPrimaryHex = draft.vinylPrimaryHex
        vinylSecondaryHex = draft.vinylSecondaryHex
        vinylSeed = draft.vinylSeed
        conditionMedia = draft.conditionMedia
        conditionSleeve = draft.conditionSleeve
        storageLocation = draft.storageLocation
        notes = draft.notes
        tracks = draft.tracks
            .filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { Track(side: $0.side, trackNumber: $0.number, title: $0.title, duration: $0.duration) }
    }
}
