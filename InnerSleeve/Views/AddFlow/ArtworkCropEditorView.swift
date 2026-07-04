import SwiftUI

struct ArtworkPreviewView: View {
    var imageData: Data?
    var artSeed: Int
    var initials: String
    var titleText: String

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Palette.offWhite, Color(red: 0.88, green: 0.87, blue: 0.84)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    artwork
                        .frame(width: side - 14, height: side - 14)
                        .clipShape(.rect(cornerRadius: 3))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: Palette.warmShadow.opacity(0.34), radius: 16, y: 10)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Album artwork")
    }

    @ViewBuilder
    private var artwork: some View {
        if let imageData {
            CoverArtworkImageView(imageData: imageData)
        } else {
            CoverArtView(seed: artSeed, style: .missing, initials: initials, titleText: titleText)
        }
    }
}

struct RecordLabelCropEditorView: View {
    var imageData: Data?
    @Binding var scale: Double
    @Binding var offsetX: Double
    @Binding var offsetY: Double
    var artSeed: Int
    var initials: String
    var titleText: String
    var vinylAppearance: VinylAppearance
    var vinylStyle: VinylStyle? = nil
    var vinylPrimaryHex: String? = nil
    var vinylSecondaryHex: String? = nil
    var vinylSeed: Int? = nil

    @State private var dragStartX: Double?
    @State private var dragStartY: Double?
    @State private var magnifyStartScale: Double?

    var body: some View {
        VStack(spacing: 14) {
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let labelSide = side * 0.37
                ZStack {
                    RecordDiscView(
                        artSeed: artSeed,
                        artStyle: .rings,
                        initials: initials,
                        titleText: titleText,
                        coverImageData: imageData,
                        labelArtScale: scale,
                        labelArtOffsetX: offsetX,
                        labelArtOffsetY: offsetY,
                        appearance: vinylAppearance,
                        vinylStyle: vinylStyle,
                        vinylPrimaryHex: vinylPrimaryHex,
                        vinylSecondaryHex: vinylSecondaryHex,
                        vinylSeed: vinylSeed,
                        glossStrength: 0.62
                    )
                    .frame(width: side, height: side)

                    Circle()
                        .strokeBorder(Palette.orangeAccent.opacity(0.45), lineWidth: 1)
                        .frame(width: labelSide, height: labelSide)
                }
                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                .contentShape(Circle())
                .gesture(dragGesture(labelSide: labelSide).simultaneously(with: magnifyGesture))
            }
            .frame(height: 206)

            HStack(spacing: 10) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.inkOnStage.opacity(0.45))
                Slider(value: $scale, in: CoverArtCropMath.minimumScale...CoverArtCropMath.maximumScale)
                    .tint(Palette.orangeAccent)
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.inkOnStage.opacity(0.45))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Record label thumbnail")
    }

    private func dragGesture(labelSide: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragStartX == nil {
                    dragStartX = offsetX
                    dragStartY = offsetY
                }
                let baseX = dragStartX ?? offsetX
                let baseY = dragStartY ?? offsetY
                offsetX = CoverArtCropMath.clampedOffset(baseX + Double(value.translation.width / labelSide))
                offsetY = CoverArtCropMath.clampedOffset(baseY + Double(value.translation.height / labelSide))
            }
            .onEnded { _ in
                dragStartX = nil
                dragStartY = nil
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if magnifyStartScale == nil {
                    magnifyStartScale = scale
                }
                scale = CoverArtCropMath.clampedScale((magnifyStartScale ?? scale) * value.magnification)
            }
            .onEnded { _ in
                magnifyStartScale = nil
            }
    }
}
