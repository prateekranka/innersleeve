import SwiftUI
import SwiftData

/// Record Detail: the album object first, everything else small and beneath it.
struct RecordDetailView: View {
    @Bindable var record: Record
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var isRefreshingArtwork = false
    @State private var artworkRefreshError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.stageGrey.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 26) {
                        SleevePullView(record: record)
                            .padding(.top, 26)

                        titleBlock

                        trackListSection
                        pressingSection
                        archiveLink
                        playHistorySection
                        notesSection
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 60)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button {
                            editing = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.glass)

                        Button {
                            Task { await refreshCover(force: true, showsError: true) }
                        } label: {
                            if isRefreshingArtwork {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .buttonStyle(.glass)
                        .disabled(isRefreshingArtwork)

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.glass)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        record.logPlay()
                    } label: {
                        Label("Log play", systemImage: "waveform")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.orangeAccent)
                }
            }
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .task(id: record.persistentModelID) {
                await refreshCover(force: false, showsError: false)
            }
        }
        .sheet(isPresented: $editing) {
            NavigationStack {
                RecordFormView(
                    draft: RecordDraft(record: record),
                    title: "Edit record",
                    saveTitle: "Save",
                    onSave: { draft in
                        record.apply(draft)
                        try? modelContext.save()
                        if draft.coverImageData == nil, let url = draft.coverArtURL {
                            Task { await loadCover(for: record, url: url) }
                        }
                    },
                    onArtworkRefetched: { draft in
                        guard let data = draft.coverImageData, let url = draft.coverArtURL else { return }
                        record.applyRefetchedArtwork(data, sourceURL: url)
                        try? modelContext.save()
                    },
                    onDelete: {
                        modelContext.delete(record)
                        try? modelContext.save()
                        dismiss()
                    }
                )
            }
        }
        .sensoryFeedback(.success, trigger: record.playCount)
    }

    @MainActor
    private func refreshCover(force: Bool, showsError: Bool) async {
        #if canImport(UIKit)
        if !CoverArtRefreshPolicy.shouldRefresh(
            existingMaxPixelDimension: record.coverImageData.flatMap(CoverArtLoader.maxPixelDimension(of:)),
            hasImageData: record.coverImageData != nil,
            force: force
        ) {
            return
        }
        #else
        if !CoverArtRefreshPolicy.shouldRefresh(
            existingMaxPixelDimension: nil,
            hasImageData: record.coverImageData != nil,
            force: force
        ) {
            return
        }
        #endif
        isRefreshingArtwork = true
        defer { isRefreshingArtwork = false }
        if let result = await CoverArtRefetcher().refetch(
            savedURL: record.highDefinitionCoverArtURL,
            artist: record.artist,
            title: record.title,
            forceLookup: force
        ) {
            record.applyRefetchedArtwork(result.data, sourceURL: result.sourceURL)
            try? modelContext.save()
            artworkRefreshError = nil
        } else if showsError {
            artworkRefreshError = "Artwork could not be refetched."
        }
    }

    @MainActor
    @discardableResult
    private func loadCover(for record: Record, url: URL) async -> Bool {
        if let data = try? await CoverArtLoader().loadData(from: url) {
            record.applyRefetchedArtwork(data, sourceURL: url)
            try? modelContext.save()
            return true
        }
        return false
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(record.title)
                .font(.system(size: 17, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.inkOnStage)
            Text("\(record.artist) · \(String(record.releaseYear)) · \(record.label)")
                .font(.system(size: 12))
                .foregroundStyle(Palette.inkOnStage.opacity(0.6))
                .multilineTextAlignment(.center)
            if let artworkRefreshError {
                Text(artworkRefreshError)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.orangeAccent)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Track list

    private var trackListSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            trackSide(title: "Side A", tracks: record.tracksSideA)
            trackSide(title: "Side B", tracks: record.tracksSideB)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trackSide(title: String, tracks: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionHeader(title)
            ForEach(tracks) { track in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(track.trackNumber)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Palette.inkOnStage.opacity(0.4))
                        .frame(width: 14, alignment: .trailing)
                    Text(track.title)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.inkOnStage)
                    if track.favorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Palette.warmYellow)
                    }
                    Spacer(minLength: 8)
                    Text(track.formattedDuration)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.inkOnStage.opacity(0.45))
                }
            }
        }
    }

    // MARK: Pressing / provenance

    private var pressingSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionHeader("Pressing & Copy")
            detailRow("Pressing", record.pressingDescription)
            detailRow("Format", record.format)
            detailRow("Vinyl", record.vinylAppearance.displayName)
            detailRow("Condition", "\(record.conditionMedia.displayName) media, \(record.conditionSleeve.displayName) sleeve")
            detailRow("Storage", record.storageLocation)
            if let date = record.purchaseDate {
                let price = record.purchasePrice.map {
                    $0.formatted(.currency(code: "USD").precision(.fractionLength(0)))
                } ?? "—"
                detailRow("Purchased", "\(date.formatted(date: .abbreviated, time: .omitted)) · \(price)")
            }
            if let value = record.estimatedValue {
                detailRow("Est. value", value.formatted(.currency(code: "USD").precision(.fractionLength(0))))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var archiveLink: some View {
        NavigationLink {
            PackageArchiveView(record: record)
        } label: {
            HStack {
                Label(
                    record.attachments.isEmpty
                        ? "Package archive · empty"
                        : "Package archive · \(record.attachments.count) items",
                    systemImage: "shippingbox"
                )
                .font(.system(size: 12, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .buttonStyle(.glass)
        .tint(Palette.inkOnStage)
    }

    // MARK: Play history / notes

    private var playHistorySection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionHeader("Play History")
            HStack(spacing: 14) {
                Text("\(record.playCount) plays")
                if let last = record.lastPlayedAt {
                    Text("last \(last.formatted(date: .abbreviated, time: .omitted))")
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Palette.inkOnStage.opacity(0.55))

            ForEach(record.sortedPlayLog.prefix(5)) { entry in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle()
                        .fill(Palette.orangeAccent.opacity(0.8))
                        .frame(width: 4, height: 4)
                        .offset(y: -2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.playedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Palette.inkOnStage.opacity(0.6))
                        if let note = entry.note, !note.isEmpty {
                            Text(note)
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.inkOnStage.opacity(0.45))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var notesSection: some View {
        if !record.notes.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                sectionHeader("Notes")
                Text(record.notes)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkOnStage.opacity(0.65))
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Bits

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .kerning(1.4)
            .foregroundStyle(Palette.inkOnStage.opacity(0.4))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Palette.inkOnStage.opacity(0.4))
                .frame(width: 74, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(Palette.inkOnStage.opacity(0.85))
        }
    }
}

#Preview("Record detail") {
    let container = PreviewContainers.full
    let record = try! container.mainContext.fetch(FetchDescriptor<Record>()).first {
        $0.title == "Night Bureau"
    }!
    return RecordDetailView(record: record)
        .modelContainer(container)
}

#Preview("Detail · long title") {
    let container = PreviewContainers.longTitles
    let record = try! container.mainContext.fetch(FetchDescriptor<Record>()).first!
    return RecordDetailView(record: record)
        .modelContainer(container)
}
