import SwiftUI

struct ShelfRoomView: View {
    @Environment(StageLight.self) private var stageLight: StageLight?

    var records: [Record]
    var onOpen: (Record) -> Void
    var onEdit: (Record) -> Void
    var onEditLook: (Record) -> Void
    var onDelete: (Record) -> Void
    var onPutOnDeck: (Record) -> Void

    @AppStorage("shelfRoomLampOn") private var lampOn = true

    private var rows: [[Record]] {
        var rows = Array(repeating: [Record](), count: 3)
        for (index, record) in records.enumerated() {
            rows[index % 3].append(record)
        }
        return rows
    }

    var body: some View {
        GeometryReader { proxy in
            let sceneHeight = max(proxy.size.height, 620)
            let shelfHeight = sceneHeight * 0.26
            let consoleHeight = sceneHeight * 0.22

            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { index in
                            ShelfRoomRowView(
                                records: rows[index],
                                shelfIndex: index,
                                onOpen: onOpen,
                                onEdit: onEdit,
                                onEditLook: onEditLook,
                                onDelete: onDelete,
                                onPutOnDeck: onPutOnDeck
                            )
                            .frame(height: shelfHeight)
                        }
                    }
                    .frame(minHeight: shelfHeight * 3)

                    ConsoleTableView(lampOn: $lampOn)
                        .frame(height: consoleHeight)
                }
                .frame(maxWidth: .infinity)
                .background(roomBackground)
                .overlay(lampOverlay)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 26)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            applyLampLight(animated: false)
        }
        .onChange(of: lampOn) { _, _ in
            applyLampLight(animated: true)
        }
    }

    private var roomBackground: some View {
        LinearGradient(
            colors: [
                Palette.stageGrey.opacity(lampOn ? 1.0 : 0.78),
                Palette.stageGreyDeep.opacity(lampOn ? 0.88 : 0.68),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var lampOverlay: some View {
        if lampOn {
            Palette.warmYellow.opacity(0.05)
        } else {
            Palette.charcoal.opacity(0.22)
        }
    }

    private func applyLampLight(animated: Bool) {
        guard let stageLight else { return }
        let update = {
            stageLight.position = lampOn ? CGPoint(x: -0.74, y: 0.62) : StageLightMath.defaultPosition
            stageLight.intensity = lampOn ? 1 : 0.35
        }
        if animated {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                update()
            }
        } else {
            update()
        }
    }
}

private struct ShelfRoomRowView: View {
    var records: [Record]
    var shelfIndex: Int
    var onOpen: (Record) -> Void
    var onEdit: (Record) -> Void
    var onEditLook: (Record) -> Void
    var onDelete: (Record) -> Void
    var onPutOnDeck: (Record) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 10)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .bottom, spacing: 18) {
                    if records.isEmpty {
                        ShelfSleevePlaceholder()
                            .frame(width: 118, height: 140)
                            .scrollTargetLayout()
                    } else {
                        ForEach(records) { record in
                            ShelfSleeveView(
                                record: record,
                                onOpen: onOpen,
                                onEdit: onEdit,
                                onEditLook: onEditLook,
                                onDelete: onDelete,
                                onPutOnDeck: onPutOnDeck
                            )
                            .frame(width: 118, height: 140)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 24, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)

            shelfLedge
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
        }
    }

    private var shelfLedge: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.77, green: 0.73, blue: 0.65),
                        Color(red: 0.52, green: 0.47, blue: 0.39),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
            )
            .shadow(color: Palette.warmShadow.opacity(0.6), radius: 10, y: 6)
    }
}

private struct ShelfSleeveView: View {
    var record: Record
    var onOpen: (Record) -> Void
    var onEdit: (Record) -> Void
    var onEditLook: (Record) -> Void
    var onDelete: (Record) -> Void
    var onPutOnDeck: (Record) -> Void

    var body: some View {
        Button {
            onOpen(record)
        } label: {
            ZStack(alignment: .top) {
                RecordDiscView(record: record, glossStrength: 0.45)
                    .frame(width: 88, height: 88)
                    .offset(y: -10)
                    .shadow(color: .black.opacity(0.18), radius: 5, y: 2)

                jacket
                    .padding(.top, 16)
            }
            .frame(width: 118, height: 140, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onEdit(record)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button {
                onEditLook(record)
            } label: {
                Label("Record look", systemImage: "record.circle")
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

    private var jacket: some View {
        RecordCoverArtworkView(record: record)
            .aspectRatio(1, contentMode: .fill)
            .frame(width: 112, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.46), lineWidth: 0.8)
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.14))
                    .frame(height: 3)
            }
            .shadow(color: Palette.warmShadow.opacity(0.62), radius: 10, y: 7)
    }
}

private struct ShelfSleevePlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .strokeBorder(
                Palette.inkOnStage.opacity(0.18),
                style: StrokeStyle(lineWidth: 1.2, dash: [6, 5])
            )
            .frame(width: 112, height: 112)
            .padding(.top, 16)
    }
}

private struct ConsoleTableView: View {
    @Binding var lampOn: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            table
            HStack(alignment: .bottom) {
                LampView(isOn: lampOn)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            lampOn.toggle()
                        }
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: lampOn)
                    .accessibilityLabel("Lamp")
                    .accessibilityAddTraits(.isButton)

                Spacer()

                RecordStackDecoration()
                    .padding(.trailing, 8)

                PlantView()
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 18)
        }
    }

    private var table: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.64, green: 0.48, blue: 0.31),
                                Color(red: 0.40, green: 0.28, blue: 0.17),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 82)
                    .shadow(color: Palette.warmShadow.opacity(0.8), radius: 14, y: 8)

                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: CGFloat(86 + index * 34), height: 1.2)
                        .offset(x: CGFloat(index * 17 - 30), y: CGFloat(16 + index * 9))
                }
            }
        }
    }
}

private struct LampView: View {
    var isOn: Bool

    var body: some View {
        ZStack {
            if isOn {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Palette.warmYellow.opacity(0.34), .clear],
                            center: .center,
                            startRadius: 2,
                            endRadius: 72
                        )
                    )
                    .frame(width: 144, height: 144)
                    .offset(y: -22)
            }

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isOn ? Palette.offWhite : Color(red: 0.74, green: 0.72, blue: 0.67))
                    .frame(width: 48, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.8)
                    )
                    .shadow(color: isOn ? Palette.warmYellow.opacity(0.28) : .clear, radius: 12)

                Rectangle()
                    .fill(Color.black.opacity(0.38))
                    .frame(width: 4, height: 42)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Palette.offWhite, Color(red: 0.72, green: 0.70, blue: 0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 38, height: 12)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.8))
            }
        }
        .frame(width: 86, height: 112)
    }
}

private struct PlantView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<7, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? Color(red: 0.22, green: 0.42, blue: 0.28) : Color(red: 0.34, green: 0.50, blue: 0.31))
                    .frame(width: 11, height: CGFloat(36 + (index % 3) * 8))
                    .rotationEffect(.degrees(Double(index - 3) * 15))
                    .offset(x: CGFloat(index - 3) * 7, y: -18 - CGFloat(index % 2) * 5)
            }

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.74, green: 0.36, blue: 0.22), Palette.offWhite.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 46, height: 34)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.8)
                )
        }
        .frame(width: 74, height: 104)
    }
}

private struct RecordStackDecoration: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Palette.offWhite)
                .frame(width: 52, height: 58)
                .rotationEffect(.degrees(-8))
                .offset(x: -24, y: -18)
                .shadow(color: Palette.warmShadow.opacity(0.45), radius: 6, y: 4)

            VStack(spacing: 3) {
                ForEach(0..<8, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Palette.labelInks[index % Palette.labelInks.count].opacity(0.78))
                        .frame(width: CGFloat(58 + (index % 3) * 4), height: 4)
                        .offset(x: CGFloat((index % 3) - 1) * 2)
                }
            }
            .shadow(color: Palette.warmShadow.opacity(0.45), radius: 5, y: 3)
        }
        .frame(width: 96, height: 90)
    }
}

#Preview("Shelf room", traits: .sizeThatFitsLayout) {
    ShelfRoomView(
        records: FixtureData.makeRecords(),
        onOpen: { _ in },
        onEdit: { _ in },
        onEditLook: { _ in },
        onDelete: { _ in },
        onPutOnDeck: { _ in }
    )
    .frame(width: 393, height: 660)
    .background(Palette.stageGrey)
}
