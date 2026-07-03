import SwiftData
import SwiftUI

struct RecordDraft {
    var artist = ""
    var title = ""
    var releaseYear = Calendar.current.component(.year, from: .now)
    var label = ""
    var format = "12\" LP, 33 RPM"
    var pressingDescription = ""
    var catalogNumber = ""
    var barcode = ""
    var sourceReference: String?
    var coverArtURL: URL?
    var coverImageData: Data?
    var coverArtScale = 1.0
    var coverArtOffsetX = 0.0
    var coverArtOffsetY = 0.0
    var labelArtScale = 1.0
    var labelArtOffsetX = 0.0
    var labelArtOffsetY = 0.0
    var vinylAppearance: VinylAppearance = .black
    var conditionMedia: ConditionGrade = .nearMint
    var conditionSleeve: ConditionGrade = .vgPlus
    var storageLocation = ""
    var notes = ""
    var tracks: [TrackDraft] = [
        TrackDraft(side: .a, number: 1, title: ""),
        TrackDraft(side: .b, number: 1, title: ""),
    ]

    init() {}

    init(candidate: ReleaseCandidate) {
        artist = candidate.artist
        title = candidate.title
        releaseYear = candidate.year ?? releaseYear
        label = candidate.label ?? ""
        format = candidate.format ?? format
        catalogNumber = candidate.catalogNumber ?? ""
        barcode = candidate.barcode ?? ""
        sourceReference = candidate.id
        coverArtURL = candidate.coverArtURL
        pressingDescription = [candidate.country, candidate.format, candidate.catalogNumber]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
        if !candidate.tracks.isEmpty {
            tracks = candidate.tracks.map {
                TrackDraft(side: $0.side ?? .a, number: $0.number, title: $0.title, duration: $0.seconds ?? 0)
            }
        }
    }

    init(record: Record) {
        artist = record.artist
        title = record.title
        releaseYear = record.releaseYear
        label = record.label
        format = record.format
        pressingDescription = record.pressingDescription
        catalogNumber = record.catalogNumber ?? ""
        barcode = record.barcode ?? ""
        sourceReference = record.sourceReference
        coverArtURL = record.highDefinitionCoverArtURL
        coverImageData = record.coverImageData
        coverArtScale = record.coverArtScaleValue
        coverArtOffsetX = record.coverArtOffsetXValue
        coverArtOffsetY = record.coverArtOffsetYValue
        labelArtScale = record.labelArtScaleValue
        labelArtOffsetX = record.labelArtOffsetXValue
        labelArtOffsetY = record.labelArtOffsetYValue
        vinylAppearance = record.vinylAppearance
        conditionMedia = record.conditionMedia
        conditionSleeve = record.conditionSleeve
        storageLocation = record.storageLocation
        notes = record.notes
        tracks = record.tracks
            .sorted { ($0.side.rawValue, $0.trackNumber) < ($1.side.rawValue, $1.trackNumber) }
            .map { TrackDraft(side: $0.side, number: $0.trackNumber, title: $0.title, duration: $0.duration) }
    }
}

struct TrackDraft: Identifiable, Equatable {
    var id = UUID()
    var side: RecordSide
    var number: Int
    var title: String
    var duration: Int = 0
}

struct RecordFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: RecordDraft
    @State private var isLoadingCover = false
    @State private var coverLoadError: String?
    var title: String = "Record"
    var saveTitle: String = "Save"
    var onSave: (RecordDraft) -> Void
    var onArtworkRefetched: ((RecordDraft) -> Void)?
    var onDelete: (() -> Void)? = nil

    init(
        draft: RecordDraft,
        title: String = "Record",
        saveTitle: String = "Save",
        onSave: @escaping (RecordDraft) -> Void,
        onArtworkRefetched: ((RecordDraft) -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        _draft = State(initialValue: draft)
        self.title = title
        self.saveTitle = saveTitle
        self.onSave = onSave
        self.onArtworkRefetched = onArtworkRefetched
        self.onDelete = onDelete
    }

    var body: some View {
        Form {
            artworkSection
            recordThumbnailSection
            identitySection
            pressingSection
            conditionSection
            copySection
            tracksSection
            if let onDelete {
                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Delete record", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(title)
        .task(id: draft.coverArtURL) {
            await loadCoverIfNeeded()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(saveTitle) {
                    onSave(draft)
                    dismiss()
                }
                .disabled(draft.artist.trimmingCharacters(in: .whitespaces).isEmpty || draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var identitySection: some View {
        Section("Identity") {
            TextField("Artist", text: $draft.artist)
            TextField("Title", text: $draft.title)
            TextField("Year", value: $draft.releaseYear, format: .number)
                .keyboardType(.numberPad)
            TextField("Label", text: $draft.label)
        }
    }

    private var pressingSection: some View {
        Section("Pressing") {
            TextField("Format", text: $draft.format)
            TextField("Pressing", text: $draft.pressingDescription)
            TextField("Catalog number", text: $draft.catalogNumber)
            TextField("Barcode", text: $draft.barcode)
            Picker("Vinyl", selection: $draft.vinylAppearance) {
                ForEach(VinylAppearance.allCases, id: \.self) { appearance in
                    Text(appearance.displayName).tag(appearance)
                }
            }
        }
    }

    private var artworkSection: some View {
        Section("Artwork") {
            ArtworkPreviewView(
                imageData: draft.coverImageData,
                artSeed: abs(draft.title.hashValue % 10_000),
                initials: draft.artist.artInitials,
                titleText: draft.title
            )
            .frame(width: 220, height: 220)
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))

            if isLoadingCover {
                ProgressView("Loading artwork")
                    .font(.system(size: 11))
            }

            if let coverLoadError {
                Text(coverLoadError)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.orangeAccent)
            }

            Button {
                Task { await loadCover(force: true) }
            } label: {
                Label("Refetch artwork", systemImage: "arrow.clockwise")
            }
            .disabled(isLoadingCover)
        }
    }

    private var recordThumbnailSection: some View {
        Section("Record thumbnail") {
            RecordLabelCropEditorView(
                imageData: draft.coverImageData,
                scale: $draft.labelArtScale,
                offsetX: $draft.labelArtOffsetX,
                offsetY: $draft.labelArtOffsetY,
                artSeed: abs(draft.title.hashValue % 10_000),
                initials: draft.artist.artInitials,
                titleText: draft.title,
                vinylAppearance: draft.vinylAppearance
            )
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))

            Button {
                draft.labelArtScale = 1
                draft.labelArtOffsetX = 0
                draft.labelArtOffsetY = 0
            } label: {
                Label("Reset thumbnail fit", systemImage: "arrow.counterclockwise")
            }
            .disabled(draft.coverImageData == nil)
        }
    }

    private var conditionSection: some View {
        Section("Condition") {
            Picker("Media", selection: $draft.conditionMedia) {
                ForEach(ConditionGrade.allCases, id: \.self) { grade in
                    Text(grade.displayName).tag(grade)
                }
            }
            Picker("Sleeve", selection: $draft.conditionSleeve) {
                ForEach(ConditionGrade.allCases, id: \.self) { grade in
                    Text(grade.displayName).tag(grade)
                }
            }
        }
    }

    private var copySection: some View {
        Section("Copy") {
            TextField("Storage location", text: $draft.storageLocation)
            TextField("Notes", text: $draft.notes, axis: .vertical)
        }
    }

    private var tracksSection: some View {
        Section("Tracks") {
            ForEach($draft.tracks) { $track in
                HStack {
                    Picker("", selection: $track.side) {
                        ForEach(RecordSide.allCases, id: \.self) { side in
                            Text(side.rawValue).tag(side)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 88)
                    TextField("#", value: $track.number, format: .number)
                        .keyboardType(.numberPad)
                        .frame(width: 36)
                    TextField("Track title", text: $track.title)
                }
            }
            .onDelete { offsets in
                draft.tracks.remove(atOffsets: offsets)
            }
            Button {
                let next = (draft.tracks.filter { $0.side == .a }.map(\.number).max() ?? 0) + 1
                draft.tracks.append(TrackDraft(side: .a, number: next, title: ""))
            } label: {
                Label("Add track", systemImage: "plus")
            }
        }
    }

    @MainActor
    private func loadCoverIfNeeded() async {
        await loadCover(force: false)
    }

    @MainActor
    private func loadCover(force: Bool) async {
        #if canImport(UIKit)
        if !CoverArtRefreshPolicy.shouldRefresh(
            existingMaxPixelDimension: draft.coverImageData.flatMap(CoverArtLoader.maxPixelDimension(of:)),
            hasImageData: draft.coverImageData != nil,
            force: force
        ) {
            return
        }
        #else
        if !CoverArtRefreshPolicy.shouldRefresh(
            existingMaxPixelDimension: nil,
            hasImageData: draft.coverImageData != nil,
            force: force
        ) {
            return
        }
        #endif
        isLoadingCover = true
        defer { isLoadingCover = false }
        if let result = await CoverArtRefetcher().refetch(
            savedURL: draft.coverArtURL,
            artist: draft.artist,
            title: draft.title,
            forceLookup: force
        ) {
            draft.coverArtURL = result.sourceURL
            draft.coverImageData = result.data
            coverLoadError = nil
            onArtworkRefetched?(draft)
        } else if force {
            coverLoadError = "Artwork could not be refetched."
        }
    }
}
