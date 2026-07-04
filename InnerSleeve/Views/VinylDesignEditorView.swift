import SwiftUI

struct VinylLookValues: Equatable {
    var style: VinylStyle
    var primaryHex: String
    var secondaryHex: String
    var seed: Int

    init(
        style: VinylStyle,
        primaryHex: String,
        secondaryHex: String,
        seed: Int
    ) {
        self.style = style
        self.primaryHex = primaryHex
        self.secondaryHex = secondaryHex
        self.seed = seed
    }

    init(record: Record) {
        self.init(
            style: record.resolvedVinylStyle,
            primaryHex: record.resolvedVinylPrimaryHex,
            secondaryHex: record.resolvedVinylSecondaryHex,
            seed: record.resolvedVinylSeed
        )
    }

    init(draft: RecordDraft) {
        self.init(
            style: draft.resolvedVinylStyle,
            primaryHex: draft.resolvedVinylPrimaryHex,
            secondaryHex: draft.resolvedVinylSecondaryHex,
            seed: draft.resolvedVinylSeed
        )
    }
}

struct VinylPreviewConfiguration {
    var artSeed: Int
    var artStyle: CoverArtStyle
    var initials: String
    var titleText: String
    var coverImageData: Data?
    var labelArtScale: Double
    var labelArtOffsetX: Double
    var labelArtOffsetY: Double
    var appearance: VinylAppearance

    init(record: Record) {
        artSeed = record.artSeed
        artStyle = record.hasCoverArt ? record.artStyle : .missing
        initials = record.artist.artInitials
        titleText = record.hasCoverArt ? "" : record.title
        coverImageData = record.coverImageData
        labelArtScale = record.labelArtScaleValue
        labelArtOffsetX = record.labelArtOffsetXValue
        labelArtOffsetY = record.labelArtOffsetYValue
        appearance = record.vinylAppearance
    }

    init(draft: RecordDraft) {
        artSeed = draft.artSeed
        artStyle = .rings
        initials = draft.artist.artInitials
        titleText = draft.title
        coverImageData = draft.coverImageData
        labelArtScale = draft.labelArtScale
        labelArtOffsetX = draft.labelArtOffsetX
        labelArtOffsetY = draft.labelArtOffsetY
        appearance = draft.vinylAppearance
    }
}

struct VinylDesignEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var values: VinylLookValues
    var preview: VinylPreviewConfiguration
    var onSave: (VinylLookValues) -> Void

    init(
        values: VinylLookValues,
        preview: VinylPreviewConfiguration,
        onSave: @escaping (VinylLookValues) -> Void
    ) {
        _values = State(initialValue: values)
        self.preview = preview
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    RecordDiscView(
                        artSeed: preview.artSeed,
                        artStyle: preview.artStyle,
                        initials: preview.initials,
                        titleText: preview.titleText,
                        coverImageData: preview.coverImageData,
                        labelArtScale: preview.labelArtScale,
                        labelArtOffsetX: preview.labelArtOffsetX,
                        labelArtOffsetY: preview.labelArtOffsetY,
                        appearance: preview.appearance,
                        vinylStyle: values.style,
                        vinylPrimaryHex: values.primaryHex,
                        vinylSecondaryHex: values.secondaryHex,
                        vinylSeed: values.seed,
                        glossStrength: 0.88
                    )
                    .frame(width: 260, height: 260)
                    .padding(.top, 10)

                    stylePicker
                    colorControls

                    Button {
                        values.seed = Int.random(in: 1...999_999)
                    } label: {
                        Label("Shuffle pattern", systemImage: "shuffle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Palette.orangeAccent)
                    .disabled(values.style == .black || values.style == .translucent)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(Palette.stageGrey.ignoresSafeArea())
            .navigationTitle("Record look")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(values)
                        dismiss()
                    }
                }
            }
        }
    }

    private var stylePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Style")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkOnStage.opacity(0.62))

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(VinylStyle.allCases, id: \.self) { style in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                values.style = style
                                applyDefaultColorsIfNeeded(for: style)
                            }
                        } label: {
                            VStack(spacing: 7) {
                                RecordDiscView(
                                    artSeed: preview.artSeed,
                                    artStyle: preview.artStyle,
                                    initials: preview.initials,
                                    titleText: preview.titleText,
                                    coverImageData: preview.coverImageData,
                                    labelArtScale: preview.labelArtScale,
                                    labelArtOffsetX: preview.labelArtOffsetX,
                                    labelArtOffsetY: preview.labelArtOffsetY,
                                    appearance: preview.appearance,
                                    vinylStyle: style,
                                    vinylPrimaryHex: previewHexes(for: style).primary,
                                    vinylSecondaryHex: previewHexes(for: style).secondary,
                                    vinylSeed: values.seed,
                                    glossStrength: 0.42
                                )
                                .frame(width: 56, height: 56)

                                Text(style.displayName)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }
                            .foregroundStyle(Palette.inkOnStage)
                            .frame(width: 74)
                            .padding(.vertical, 8)
                            .background {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(style == values.style ? Palette.offWhite : Color.white.opacity(0.48))
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(style == values.style ? Palette.orangeAccent : Color.clear, lineWidth: 1.2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var colorControls: some View {
        if values.style != .black {
            VStack(spacing: 12) {
                ColorPicker(
                    "Primary color",
                    selection: colorBinding(\.primaryHex),
                    supportsOpacity: false
                )

                if values.style.usesSecondaryColor {
                    ColorPicker(
                        "Secondary color",
                        selection: colorBinding(\.secondaryHex),
                        supportsOpacity: false
                    )
                }
            }
            .font(.system(size: 14, weight: .medium))
            .padding(14)
            .background(Color.white.opacity(0.54), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func colorBinding(_ keyPath: WritableKeyPath<VinylLookValues, String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: values[keyPath: keyPath]) ?? Palette.orangeAccent },
            set: { newValue in
                if let hex = newValue.hexString {
                    values[keyPath: keyPath] = hex
                }
            }
        )
    }

    private func previewHexes(for style: VinylStyle) -> (primary: String, secondary: String) {
        if style == values.style {
            return (values.primaryHex, values.secondaryHex)
        }
        return Record.defaultVinylColors(for: style, legacyAppearance: preview.appearance)
    }

    private func applyDefaultColorsIfNeeded(for style: VinylStyle) {
        let defaults = Record.defaultVinylColors(for: style, legacyAppearance: preview.appearance)
        if values.primaryHex.isEmpty {
            values.primaryHex = defaults.primary
        }
        if values.secondaryHex.isEmpty {
            values.secondaryHex = defaults.secondary
        }
    }
}

private extension VinylStyle {
    var usesSecondaryColor: Bool {
        switch self {
        case .black, .translucent, .smoke:
            return false
        case .swirl, .marble, .pinwheel, .burst, .halo, .splatterMix:
            return true
        }
    }
}
