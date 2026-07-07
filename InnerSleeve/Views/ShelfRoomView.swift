import SwiftUI

/// The display shelf: a listening-room wall modeled on the reference photos.
/// Album covers face out on wall-mounted picture ledges in a grid; a tripod
/// floor lamp lights the room from the left, and a wooden credenza with a
/// turntable and crates of records sits on the floor beneath the wall.
struct ShelfRoomView: View {
    @Environment(StageLight.self) private var stageLight: StageLight?

    var records: [Record]
    var onOpen: (Record) -> Void
    var onEdit: (Record) -> Void
    var onEditLook: (Record) -> Void
    var onDelete: (Record) -> Void
    var onPutOnDeck: (Record) -> Void

    @AppStorage("shelfRoomLampOn") private var lampOn = true

    private let gridColumns = [
        GridItem(.adaptive(minimum: 92, maximum: 128), spacing: 16, alignment: .bottom)
    ]

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                recordWall
                    .padding(.top, 30)
                    .padding(.horizontal, 22)

                floorScene
                    .padding(.top, 34)
            }
            .frame(maxWidth: .infinity)
            .background(roomBackground)
            .overlay(lampWash.allowsHitTesting(false))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            applyLampLight(animated: false)
        }
        .onChange(of: lampOn) { _, _ in
            applyLampLight(animated: true)
        }
    }

    // MARK: Wall of records

    @ViewBuilder
    private var recordWall: some View {
        LazyVGrid(columns: gridColumns, spacing: 26) {
            if records.isEmpty {
                ForEach(0..<3, id: \.self) { _ in
                    WallLedgePlaceholder()
                }
            } else {
                ForEach(records) { record in
                    WallLedgeSleeveView(
                        record: record,
                        lampOn: lampOn,
                        onOpen: onOpen,
                        onEdit: onEdit,
                        onEditLook: onEditLook,
                        onDelete: onDelete,
                        onPutOnDeck: onPutOnDeck
                    )
                }
            }
        }
    }

    // MARK: Floor scene

    private var floorScene: some View {
        ZStack(alignment: .bottom) {
            floorBoards

            HStack(alignment: .bottom, spacing: 6) {
                FloorLampView(isOn: lampOn)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            lampOn.toggle()
                        }
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: lampOn)
                    .accessibilityLabel(lampOn ? "Lamp, on" : "Lamp, off")
                    .accessibilityAddTraits(.isButton)

                ConsoleView(lampOn: lampOn)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
    }

    private var floorBoards: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1.5)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.72, green: 0.58, blue: 0.42).opacity(lampOn ? 1.0 : 0.8),
                            Color(red: 0.58, green: 0.44, blue: 0.30).opacity(lampOn ? 0.95 : 0.75),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 64)
                .overlay(alignment: .top) {
                    HStack(spacing: 46) {
                        ForEach(0..<6, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.black.opacity(0.07))
                                .frame(width: 1)
                        }
                    }
                    .frame(height: 64)
                }
        }
    }

    // MARK: Room light

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
    private var lampWash: some View {
        if lampOn {
            LinearGradient(
                colors: [Palette.warmYellow.opacity(0.10), Palette.warmYellow.opacity(0.02)],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
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

// MARK: - Wall ledge with a record on it

private struct WallLedgeSleeveView: View {
    var record: Record
    var lampOn: Bool
    var onOpen: (Record) -> Void
    var onEdit: (Record) -> Void
    var onEditLook: (Record) -> Void
    var onDelete: (Record) -> Void
    var onPutOnDeck: (Record) -> Void

    var body: some View {
        Button {
            onOpen(record)
        } label: {
            VStack(spacing: 0) {
                jacket
                ledge
            }
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
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.7)
            )
            .overlay(alignment: .leading) {
                // Spine shading so the jacket reads as a physical sleeve.
                Rectangle()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 2.5)
            }
            .shadow(color: Palette.warmShadow.opacity(lampOn ? 0.7 : 0.5), radius: 9, y: 6)
    }

    private var ledge: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.46, green: 0.30, blue: 0.19),
                        Color(red: 0.30, green: 0.19, blue: 0.12),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
            )
            .frame(height: 7)
            .padding(.horizontal, -5)
            .shadow(color: Palette.warmShadow.opacity(0.55), radius: 7, y: 5)
    }
}

private struct WallLedgePlaceholder: View {
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(
                    Palette.inkOnStage.opacity(0.18),
                    style: StrokeStyle(lineWidth: 1.2, dash: [6, 5])
                )
                .aspectRatio(1, contentMode: .fit)
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Palette.inkOnStage.opacity(0.12))
                .frame(height: 7)
                .padding(.horizontal, -5)
        }
    }
}

// MARK: - Tripod floor lamp

private struct FloorLampView: View {
    var isOn: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            if isOn {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Palette.warmYellow.opacity(0.38), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 96
                        )
                    )
                    .frame(width: 192, height: 192)
                    .offset(y: -96)
            }

            VStack(spacing: 0) {
                LampShadeShape()
                    .fill(
                        LinearGradient(
                            colors: isOn
                                ? [Palette.offWhite, Color(red: 0.93, green: 0.88, blue: 0.76)]
                                : [Color(red: 0.78, green: 0.76, blue: 0.71), Color(red: 0.68, green: 0.66, blue: 0.61)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        LampShadeShape()
                            .stroke(Color.black.opacity(0.12), lineWidth: 0.8)
                    )
                    .frame(width: 58, height: 40)
                    .shadow(color: isOn ? Palette.warmYellow.opacity(0.35) : .clear, radius: 14)

                tripod
            }
        }
        .frame(width: 96, height: 158, alignment: .bottom)
        .contentShape(Rectangle())
    }

    private var tripod: some View {
        ZStack(alignment: .top) {
            // Back leg, then the two splayed front legs.
            legLine(angle: 0)
            legLine(angle: -13)
            legLine(angle: 13)
        }
        .frame(width: 72, height: 108, alignment: .top)
    }

    private func legLine(angle: Double) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.80, green: 0.66, blue: 0.47),
                        Color(red: 0.64, green: 0.50, blue: 0.34),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4.5, height: 108)
            .rotationEffect(.degrees(angle), anchor: .top)
    }
}

private struct LampShadeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.width * 0.16
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Credenza with turntable and record crates

private struct ConsoleView: View {
    var lampOn: Bool

    var body: some View {
        VStack(spacing: 0) {
            deckOnTop
            consoleBody
        }
    }

    private var deckOnTop: some View {
        HStack(alignment: .bottom, spacing: 14) {
            speaker
            MiniTurntableView()
            speaker
        }
        .padding(.bottom, 2)
    }

    private var speaker: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.16, green: 0.16, blue: 0.16), Color(red: 0.09, green: 0.09, blue: 0.09)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 20, height: 30)
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                    .frame(width: 11, height: 11)
            )
    }

    private var consoleBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.64, green: 0.48, blue: 0.31),
                            Color(red: 0.42, green: 0.30, blue: 0.18),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Palette.warmShadow.opacity(0.8), radius: 14, y: 8)

            HStack(spacing: 10) {
                RecordCrateView(seed: 3)
                RecordCrateView(seed: 11)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .frame(height: 72)
    }
}

/// A cubby full of record spines, like the crates in the reference photo.
private struct RecordCrateView: View {
    var seed: Int

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.black.opacity(0.42))

            spines
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
        }
    }

    private var spines: some View {
        var rng = SeededRandom(seed: seed)
        let count = 18
        let heights = (0..<count).map { _ in CGFloat(rng.int(in: 34...46)) }
        let inks = (0..<count).map { _ in rng.pick(Palette.labelInks) }
        let leans = (0..<count).map { _ in Double(rng.int(in: -2...2)) }

        return HStack(alignment: .bottom, spacing: 1.6) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 0.8, style: .continuous)
                    .fill(inks[index].opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .frame(height: heights[index])
                    .rotationEffect(.degrees(leans[index]), anchor: .bottom)
            }
        }
    }
}

/// The turntable sitting on the credenza, echoing the deck in Deck mode.
private struct MiniTurntableView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Palette.offWhite, Color(red: 0.88, green: 0.87, blue: 0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.14), lineWidth: 0.8)
                )
                .shadow(color: Palette.warmShadow.opacity(0.5), radius: 4, y: 3)

            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Palette.vinylBlack)
                        .frame(width: 30, height: 30)
                    Circle()
                        .fill(Palette.warmYellow.opacity(0.85))
                        .frame(width: 9, height: 9)
                }

                VStack(alignment: .trailing, spacing: 4) {
                    Capsule()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 16, height: 2.5)
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Palette.amberDisplay.opacity(0.8))
                        .frame(width: 12, height: 3.5)
                }
            }
        }
        .frame(width: 84, height: 42)
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

#Preview("Shelf room · empty", traits: .sizeThatFitsLayout) {
    ShelfRoomView(
        records: [],
        onOpen: { _ in },
        onEdit: { _ in },
        onEditLook: { _ in },
        onDelete: { _ in },
        onPutOnDeck: { _ in }
    )
    .frame(width: 393, height: 660)
    .background(Palette.stageGrey)
}
