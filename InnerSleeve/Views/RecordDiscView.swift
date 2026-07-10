import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A physically rendered vinyl record: grooves, gloss, label, spindle hole.
/// Pure custom rendering — deliberately not a glass card.
struct RecordDiscView: View {
    @Environment(StageLight.self) private var stageLight: StageLight?

    var artSeed: Int
    var artStyle: CoverArtStyle
    var initials: String
    var titleText: String = ""
    var coverImageData: Data? = nil
    var labelArtScale: Double = 1
    var labelArtOffsetX: Double = 0
    var labelArtOffsetY: Double = 0
    var appearance: VinylAppearance = .black
    var vinylStyle: VinylStyle? = nil
    var vinylPrimaryHex: String? = nil
    var vinylSecondaryHex: String? = nil
    var vinylSeed: Int? = nil
    /// 0...1, how strong the gloss crescent reads. Lower for far carousel discs.
    var glossStrength: Double = 1.0

    private var resolvedStyle: VinylStyle {
        vinylStyle ?? VinylStyle.legacyFallback(from: appearance)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let light = stageLight ?? StageLight()
            ZStack {
                VinylSurfaceView(
                    style: resolvedStyle,
                    primary: Color(hex: vinylPrimaryHex ?? legacyDefaultColors.primary) ?? Palette.vinylBlack,
                    secondary: Color(hex: vinylSecondaryHex ?? legacyDefaultColors.secondary) ?? Palette.softBlack,
                    seed: vinylSeed ?? artSeed,
                    size: size
                )
                // Concentric groove rings read as black lines on colored pressings;
                // keep them only on Classic Black.
                if resolvedStyle == .black {
                    grooves(size: size)
                }
                iridescence(size: size, light: light)
                gloss(size: size, light: light)
                label(size: size)
                spindleHole(size: size)
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Layers

    private func grooves(size: CGFloat) -> some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let outer = size * 0.492
            let labelEdge = size * 0.20
            // Grooves need real estate; skip on tiny discs to avoid degenerate ranges.
            guard labelEdge + 10 < outer - 6 else { return }
            var rng = SeededRandom(seed: artSeed &+ 7)

            // Fine grooves.
            var radius = labelEdge + 2
            while radius < outer {
                let step = CGFloat(rng.double(in: 1.6...3.4))
                let brightness = rng.double(in: 0.02...0.05)
                let ring = Path(ellipseIn: CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2
                ))
                context.stroke(ring, with: .color(.white.opacity(brightness)), lineWidth: 0.6)
                radius += step
            }

            // A few darker track-separator bands.
            for _ in 0..<3 {
                let r = CGFloat(rng.double(in: Double(labelEdge + 8)...Double(outer - 6)))
                let ring = Path(ellipseIn: CGRect(
                    x: center.x - r, y: center.y - r,
                    width: r * 2, height: r * 2
                ))
                context.stroke(ring, with: .color(.black.opacity(0.5)), lineWidth: 1.6)
            }

            // Outer rim edge.
            let rim = Path(ellipseIn: CGRect(
                x: center.x - outer, y: center.y - outer,
                width: outer * 2, height: outer * 2
            ))
            context.stroke(rim, with: .color(.white.opacity(0.10)), lineWidth: 1)
        }
    }

    private func iridescence(size: CGFloat, light: StageLight) -> some View {
        let proximity = StageLightMath.proximity(from: light.position)
        let styleMultiplier = iridescenceMultiplier
        let strength = min(0.12, 0.035 + 0.085 * proximity * light.intensity * glossStrength * styleMultiplier)

        return Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [
                        Color.cyan.opacity(strength),
                        Color.blue.opacity(strength * 0.78),
                        Color.purple.opacity(strength * 0.92),
                        Palette.warmYellow.opacity(strength * 0.76),
                        Color.cyan.opacity(strength),
                    ],
                    center: .center,
                    angle: .degrees(StageLightMath.angle(from: light.position))
                ),
                lineWidth: size * 0.29
            )
            .padding(size * 0.08)
            .rotationEffect(.degrees(StageLightMath.angle(from: light.position)))
            .blendMode(.plusLighter)
            .opacity(light.intensity > 0 ? 1 : 0)
    }

    private func gloss(size: CGFloat, light: StageLight) -> some View {
        // Two soft crescent highlights, like studio lighting on the reference boards.
        let proximity = StageLightMath.proximity(from: light.position)
        let lightStrength = glossStrength * light.intensity * (0.45 + 0.55 * proximity)
        return ZStack {
            Circle()
                .trim(from: 0.54, to: 0.72)
                .stroke(
                    Color.white.opacity(0.11 * lightStrength),
                    style: StrokeStyle(lineWidth: size * 0.13, lineCap: .round)
                )
                .padding(size * 0.11)
                .blur(radius: size * 0.02)
            Circle()
                .trim(from: 0.06, to: 0.16)
                .stroke(
                    Color.white.opacity(0.07 * lightStrength),
                    style: StrokeStyle(lineWidth: size * 0.10, lineCap: .round)
                )
                .padding(size * 0.13)
                .blur(radius: size * 0.025)
        }
        .rotationEffect(.degrees(StageLightMath.angle(from: light.position)))
    }

    private func label(size: CGFloat) -> some View {
        ZStack {
            #if canImport(UIKit)
            if let coverImageData {
                CoverArtworkImageView(
                    imageData: coverImageData,
                    scale: labelArtScale,
                    offsetX: labelArtOffsetX,
                    offsetY: labelArtOffsetY
                )
            } else {
                CoverArtView(seed: artSeed, style: artStyle, initials: initials, titleText: titleText)
            }
            #else
            CoverArtView(seed: artSeed, style: artStyle, initials: initials, titleText: titleText)
            #endif
        }
        .frame(width: size * 0.37, height: size * 0.37)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(Color.black.opacity(0.55), lineWidth: 1)
        )
    }

    private func spindleHole(size: CGFloat) -> some View {
        Circle()
            .fill(Palette.stageGrey)
            .frame(width: size * 0.028, height: size * 0.028)
            .overlay(
                Circle().strokeBorder(Color.black.opacity(0.6), lineWidth: 0.8)
            )
    }

    private var legacyDefaultColors: (primary: String, secondary: String) {
        Record.defaultVinylColors(for: resolvedStyle, legacyAppearance: appearance)
    }

    private var iridescenceMultiplier: Double {
        switch resolvedStyle {
        case .black:
            return 0.7
        case .translucent, .halo, .burst:
            return 1.18
        case .smoke:
            return 0.86
        case .swirl, .marble, .pinwheel, .splatterMix:
            return 1.0
        }
    }
}

extension RecordDiscView {
    init(record: Record, glossStrength: Double = 1.0) {
        self.init(
            artSeed: record.artSeed,
            artStyle: record.hasCoverArt ? record.artStyle : .missing,
            initials: record.artist.artInitials,
            titleText: record.hasCoverArt ? "" : record.title,
            coverImageData: record.coverImageData,
            labelArtScale: record.labelArtScaleValue,
            labelArtOffsetX: record.labelArtOffsetXValue,
            labelArtOffsetY: record.labelArtOffsetYValue,
            appearance: record.vinylAppearance,
            vinylStyle: record.resolvedVinylStyle,
            vinylPrimaryHex: record.resolvedVinylPrimaryHex,
            vinylSecondaryHex: record.resolvedVinylSecondaryHex,
            vinylSeed: record.resolvedVinylSeed,
            glossStrength: glossStrength
        )
    }

    init(wishlistItem: WishlistItem, glossStrength: Double = 1.0) {
        self.init(
            artSeed: wishlistItem.artSeed,
            artStyle: wishlistItem.artStyle,
            initials: wishlistItem.artist.artInitials,
            appearance: .black,
            glossStrength: glossStrength
        )
    }
}

#Preview("Vinyl pressing processes", traits: .sizeThatFitsLayout) {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 18)], spacing: 18) {
        ForEach(VinylStyle.allCases, id: \.self) { style in
            let colors = Record.defaultVinylColors(for: style)
            VStack(spacing: 7) {
                RecordDiscView(
                    artSeed: 106,
                    artStyle: .rings,
                    initials: "WL",
                    vinylStyle: style,
                    vinylPrimaryHex: colors.primary,
                    vinylSecondaryHex: colors.secondary,
                    vinylSeed: 106
                )
                .frame(width: 126, height: 126)

                Text(style.displayName)
                    .font(.caption.weight(.semibold))
            }
        }
    }
    .padding(24)
    .frame(width: 460)
    .background(Palette.stageGrey)
}
