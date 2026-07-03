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
    @State private var deleteRecord: Record? = nil
    @State private var pendingSelectionID: PersistentIdentifier?
    @State private var shelfMode: ShelfMode = .carousel
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
                        .frame(height: 420)
                        .frame(maxHeight: .infinity, alignment: .center)

                        metadataBlock
                            .padding(.bottom, 96)

                    case .displayShelf:
                        DisplayShelfGridView(
                            records: records,
                            onOpen: { detailRecord = $0 },
                            onEdit: { editRecord = $0 },
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

                HStack(spacing: 6) {
                    Button {
                        shelfMode = .carousel
                    } label: {
                        Image(systemName: "circle.grid.cross")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                    .tint(shelfMode == .carousel ? Palette.orangeAccent : Palette.inkOnStage)
                    .opacity(shelfMode == .carousel ? 1 : 0.68)
                    .accessibilityLabel("Carousel shelf")

                    Button {
                        shelfMode = .displayShelf
                    } label: {
                        Image(systemName: "square.grid.3x2")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                    .tint(shelfMode == .displayShelf ? Palette.orangeAccent : Palette.inkOnStage)
                    .opacity(shelfMode == .displayShelf ? 1 : 0.68)
                    .accessibilityLabel("Display shelf")
                }

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
}

private enum ShelfMode {
    case carousel
    case displayShelf
}

private struct DisplayShelfGridView: View {
    var records: [Record]
    var onOpen: (Record) -> Void
    var onEdit: (Record) -> Void
    var onDelete: (Record) -> Void
    var onPutOnDeck: (Record) -> Void

    var body: some View {
        GeometryReader { proxy in
            let columns = proxy.size.width >= 390 ? 3 : 2
            let rows = DisplayShelfRow.rows(from: records, columns: columns)

            ScrollView(.vertical) {
                LazyVStack(spacing: 22) {
                    ForEach(rows) { row in
                        DisplayShelfRowView(
                            row: row,
                            columns: columns,
                            onOpen: onOpen,
                            onEdit: onEdit,
                            onDelete: onDelete,
                            onPutOnDeck: onPutOnDeck
                        )
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct DisplayShelfRow: Identifiable {
    var id: String
    var records: [Record]

    static func rows(from records: [Record], columns: Int) -> [DisplayShelfRow] {
        guard columns > 0 else { return [] }
        return stride(from: 0, to: records.count, by: columns).map { start in
            let end = min(start + columns, records.count)
            let rowRecords = Array(records[start..<end])
            let id = rowRecords
                .map { String(describing: $0.persistentModelID) }
                .joined(separator: "-")
            return DisplayShelfRow(id: id, records: rowRecords)
        }
    }
}

private struct DisplayShelfRowView: View {
    var row: DisplayShelfRow
    var columns: Int
    var onOpen: (Record) -> Void
    var onEdit: (Record) -> Void
    var onDelete: (Record) -> Void
    var onPutOnDeck: (Record) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(row.records) { record in
                    DisplayShelfRecordButton(
                        record: record,
                        onOpen: onOpen,
                        onEdit: onEdit,
                        onDelete: onDelete,
                        onPutOnDeck: onPutOnDeck
                    )
                    .frame(maxWidth: .infinity)
                }

                if row.records.count < columns {
                    ForEach(0..<(columns - row.records.count), id: \.self) { _ in
                        Color.clear
                            .aspectRatio(0.72, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 8)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.76, green: 0.73, blue: 0.68),
                            Color(red: 0.55, green: 0.51, blue: 0.45),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 10)
                .shadow(color: Palette.warmShadow.opacity(0.65), radius: 10, y: 6)
        }
    }
}

private struct DisplayShelfRecordButton: View {
    var record: Record
    var onOpen: (Record) -> Void
    var onEdit: (Record) -> Void
    var onDelete: (Record) -> Void
    var onPutOnDeck: (Record) -> Void

    var body: some View {
        Button {
            onOpen(record)
        } label: {
            VStack(spacing: 8) {
                RecordDiscView(record: record, glossStrength: 0.7)
                    .aspectRatio(1, contentMode: .fit)
                    .shadow(color: Palette.warmShadow.opacity(0.55), radius: 12, y: 8)

                VStack(spacing: 2) {
                    Text(record.title)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                    Text(record.artist)
                        .font(.system(size: 9))
                        .lineLimit(1)
                        .foregroundStyle(Palette.inkOnStage.opacity(0.58))
                }
                .foregroundStyle(Palette.inkOnStage)
                .multilineTextAlignment(.center)
                .frame(height: 26)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(0.72, contentMode: .fit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onEdit(record)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete(record)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                onPutOnDeck(record)
            } label: {
                Label("Put on deck", systemImage: "dial.medium")
            }
        }
        .accessibilityLabel("\(record.title), \(record.artist)")
    }
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
