import SwiftUI
import SwiftData

/// The first screen: a draggable 3D shelf of records on a pale grey stage.
struct CollectionGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allRecords: [Record]
    @State private var selection: Int = 0
    @State private var detailRecord: Record? = nil
    @State private var addFlowPresented = false
    @State private var settingsPresented = false
    @State private var editRecord: Record? = nil
    @State private var lookRecord: Record? = nil
    @State private var deleteRecord: Record? = nil
    @State private var pendingSelectionID: PersistentIdentifier?
    @State private var shelfMode: ShelfMode = .carousel
    @State private var relightMode = false
    var onPutOnDeck: (Record) -> Void = { _ in }

    private var records: [Record] {
        Record.shelfOrder(allRecords)
    }

    private var selectedRecord: Record? {
        guard records.indices.contains(selection) else { return nil }
        return records[selection]
    }

    var body: some View {
        ZStack {
            Palette.stageGrey.ignoresSafeArea()

            if records.isEmpty {
                emptyShelf
            } else {
                VStack(spacing: 0) {
                    Text("The Shelf")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.inkOnStage.opacity(0.8))
                        .padding(.top, 78)

                    switch shelfMode {
                    case .carousel:
                        ZStack {
                            DepthCarouselView(
                                items: records,
                                selection: $selection,
                                discDiameter: 340,
                                onHeroTap: { detailRecord = $0 }
                            ) { record, isSelected in
                                RecordDiscView(record: record, glossStrength: isSelected ? 1.0 : 0.5)
                                    .contextMenu {
                                        if isSelected {
                                            recordContextMenu(for: record)
                                        }
                                    }
                            }

                            if relightMode {
                                StageLightControl()
                                    .frame(width: 340, height: 340)
                                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                                    .zIndex(10)
                            }
                        }
                        .frame(height: 420)
                        .frame(maxHeight: .infinity, alignment: .center)

                        metadataBlock
                            .padding(.bottom, 96)

                    case .displayShelf:
                        ShelfRoomView(
                            records: records,
                            onOpen: { detailRecord = $0 },
                            onEdit: { editRecord = $0 },
                            onEditLook: { lookRecord = $0 },
                            onDelete: { deleteRecord = $0 },
                            onPutOnDeck: onPutOnDeck
                        )
                        .padding(.top, 18)
                        .padding(.bottom, 94)
                    }
                }
            }

            shelfChrome
        }
        .sheet(item: $detailRecord) { record in
            RecordDetailView(record: record)
        }
        .sheet(isPresented: $addFlowPresented) {
            AddRecordFlow { record in
                pendingSelectionID = record.persistentModelID
            }
        }
        .sheet(isPresented: $settingsPresented) {
            NavigationStack {
                SettingsView()
            }
        }
        .sheet(item: $editRecord) { record in
            NavigationStack {
                RecordFormView(
                    draft: RecordDraft(record: record),
                    title: "Edit record",
                    saveTitle: "Save",
                    onSave: { draft in
                        record.apply(draft)
                        try? modelContext.save()
                    },
                    onDelete: {
                        delete(record)
                    }
                )
            }
        }
        .sheet(item: $lookRecord) { record in
            VinylDesignEditorView(
                values: VinylLookValues(record: record),
                preview: VinylPreviewConfiguration(record: record)
            ) { values in
                record.vinylStyleRaw = values.style.rawValue
                record.vinylPrimaryHex = values.primaryHex
                record.vinylSecondaryHex = values.secondaryHex
                record.vinylSeed = values.seed
                try? modelContext.save()
            }
        }
        .confirmationDialog(
            "Delete \(deleteRecord?.title ?? "record")?",
            isPresented: Binding(
                get: { deleteRecord != nil },
                set: { if !$0 { deleteRecord = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete record", role: .destructive) {
                if let deleteRecord {
                    delete(deleteRecord)
                }
                deleteRecord = nil
            }
            Button("Cancel", role: .cancel) {
                deleteRecord = nil
            }
        }
        .onChange(of: records.map(\.persistentModelID)) { _, _ in
            applyPendingSelection()
        }
    }

    private var shelfChrome: some View {
        VStack {
            HStack {
                Button {
                    settingsPresented = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.glass)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        shelfMode = shelfMode == .carousel ? .displayShelf : .carousel
                    }
                } label: {
                    Image(systemName: shelfMode == .carousel ? "square.split.bottomrightquarter" : "circle.grid.cross")
                        .font(.system(size: 12, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glass)
                .tint(Palette.inkOnStage)
                .accessibilityLabel(shelfMode == .carousel ? "Show display shelf" : "Show carousel")

                Spacer()

                Button {
                    addFlowPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.glassProminent)
                .tint(Palette.orangeAccent)
            }
            .tint(Palette.inkOnStage)
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Spacer()
        }
    }

    private func applyPendingSelection() {
        guard let pendingSelectionID,
              let index = records.firstIndex(where: { $0.persistentModelID == pendingSelectionID }) else {
            return
        }
        selection = index
        self.pendingSelectionID = nil
    }

    private func delete(_ record: Record) {
        if detailRecord?.persistentModelID == record.persistentModelID {
            detailRecord = nil
        }
        if editRecord?.persistentModelID == record.persistentModelID {
            editRecord = nil
        }
        modelContext.delete(record)
        try? modelContext.save()
        selection = min(selection, max(records.count - 2, 0))
    }

    // MARK: Metadata under the hero record

    private var metadataBlock: some View {
        VStack(spacing: 5) {
            if let record = selectedRecord {
                VStack(spacing: 3) {
                    Text(record.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.inkOnStage)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(record.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.inkOnStage.opacity(0.65))
                    Text(record.pressingDescription)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.inkOnStage.opacity(0.5))
                        .padding(.top, 2)
                    HStack(spacing: 10) {
                        Text(record.conditionSummary)
                        Text(lastPlayedText(for: record))
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Palette.inkOnStage.opacity(0.45))
                    .padding(.top, 1)
                }
                .id(record.persistentModelID)
                .transition(.opacity)
            }

        }
        .overlay(alignment: .trailing) {
            if shelfMode == .carousel {
                relightButton
            }
        }
        .padding(.horizontal, 36)
        .animation(.easeInOut(duration: 0.22), value: selection)
    }

    private var emptyShelf: some View {
        VStack(spacing: 18) {
            Circle()
                .strokeBorder(
                    Palette.inkOnStage.opacity(0.25),
                    style: StrokeStyle(lineWidth: 2, dash: [7, 7])
                )
                .frame(width: 220, height: 220)
                .overlay(
                    Circle()
                        .strokeBorder(Palette.inkOnStage.opacity(0.18), lineWidth: 1)
                        .frame(width: 82, height: 82)
                )
            Text("The shelf is empty")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.inkOnStage.opacity(0.7))
            Text("Records you add will line up here,\narranged in depth like a real crate.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.inkOnStage.opacity(0.45))
                .multilineTextAlignment(.center)
        }
    }

    private func lastPlayedText(for record: Record) -> String {
        guard let lastPlayed = record.lastPlayedAt else { return "never played" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "played " + formatter.localizedString(for: lastPlayed, relativeTo: .now)
    }

    @ViewBuilder
    private func recordContextMenu(for record: Record) -> some View {
        Button {
            editRecord = record
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        Button {
            lookRecord = record
        } label: {
            Label("Record look", systemImage: "record.circle")
        }
        Button(role: .destructive) {
            deleteRecord = record
        } label: {
            Label("Delete", systemImage: "trash")
        }
        Button {
            onPutOnDeck(record)
        } label: {
            Label("Put on deck", systemImage: "dial.medium")
        }
    }

    @ViewBuilder
    private var relightButton: some View {
        let button = Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                relightMode.toggle()
            }
        } label: {
            Image(systemName: relightMode ? "sun.max.fill" : "sun.max")
                .font(.system(size: 12, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(relightMode ? "Hide relight control" : "Relight records")
        .offset(x: 10, y: -2)

        if relightMode {
            button
                .buttonStyle(.glassProminent)
                .tint(Palette.warmYellow)
        } else {
            button
                .buttonStyle(.glass)
                .tint(Palette.inkOnStage)
        }
    }
}

private enum ShelfMode {
    case carousel
    case displayShelf
}

#Preview("Full collection") {
    CollectionGalleryView()
        .modelContainer(PreviewContainers.full)
}

#Preview("Empty collection") {
    CollectionGalleryView()
        .modelContainer(PreviewContainers.empty)
}

#Preview("Long album titles") {
    CollectionGalleryView()
        .modelContainer(PreviewContainers.longTitles)
}

#Preview("Missing cover image") {
    CollectionGalleryView()
        .modelContainer(PreviewContainers.missingCover)
}
