import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A physically rendered vinyl record: grooves, gloss, label, spindle hole.
/// Pure custom rendering — deliberately not a glass card.
struct RecordDiscView: View {
    var artSeed: Int
    var artStyle: CoverArtStyle
    var initials: String
    var titleText: String = ""
    var coverImageData: Data? = nil
    var labelArtScale: Double = 1
    var labelArtOffsetX: Double = 0
    var labelArtOffsetY: Double = 0
    var appearance: VinylAppearance = .black
    /// 0...1, how strong the gloss crescent reads. Lower for far carousel discs.
    var glossStrength: Double = 1.0

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                vinylBase(size: size)
                grooves(size: size)
                if appearance == .splatter {
                    splatter(size: size)
                }
                gloss(size: size)
                label(size: size)
                spindleHole(size: size)
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Layers

    private func vinylBase(size: CGFloat) -> some View {
        let colors: [Color]
        switch appearance {
        case .black:
            colors = [Color(red: 0.13, green: 0.13, blue: 0.13), Palette.vinylBlack]
        case .amber:
            colors = [Palette.amberDisplay.opacity(0.92), Color(red: 0.55, green: 0.33, blue: 0.05)]
        case .smoke:
            colors = [Color(red: 0.38, green: 0.38, blue: 0.40).opacity(0.95), Color(red: 0.10, green: 0.10, blue: 0.11)]
        case .splatter:
            colors = [Color(red: 0.16, green: 0.15, blue: 0.14), Palette.vinylBlack]
        }
        return Circle()
            .fill(
                RadialGradient(
                    colors: colors,
                    center: .center,
                    startRadius: size * 0.05,
                    endRadius: size * 0.52
                )
            )
    }

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

    private func splatter(size: CGFloat) -> some View {
        Canvas { context, canvasSize in
            var rng = SeededRandom(seed: artSeed &+ 99)
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let maxR = size * 0.47
            for _ in 0..<70 {
                let angle = rng.double(in: 0...(2 * .pi))
                let distance = CGFloat(rng.double(in: 0.22...1.0)) * maxR
                let dotR = CGFloat(rng.double(in: 0.8...3.4))
                let x = center.x + cos(angle) * distance
                let y = center.y + sin(angle) * distance
                let color = rng.double(in: 0...1) > 0.4 ? Palette.orangeAccent : Palette.warmYellow
                context.fill(
                    Path(ellipseIn: CGRect(x: x - dotR, y: y - dotR, width: dotR * 2, height: dotR * 2)),
                    with: .color(color.opacity(rng.double(in: 0.5...0.9)))
                )
            }
        }
        .clipShape(Circle())
    }

    private func gloss(size: CGFloat) -> some View {
        // Two soft crescent highlights, like studio lighting on the reference boards.
        ZStack {
            Circle()
                .trim(from: 0.54, to: 0.72)
                .stroke(
                    Color.white.opacity(0.11 * glossStrength),
                    style: StrokeStyle(lineWidth: size * 0.13, lineCap: .round)
                )
                .padding(size * 0.11)
                .blur(radius: size * 0.02)
            Circle()
                .trim(from: 0.06, to: 0.16)
                .stroke(
                    Color.white.opacity(0.07 * glossStrength),
                    style: StrokeStyle(lineWidth: size * 0.10, lineCap: .round)
                )
                .padding(size * 0.13)
                .blur(radius: size * 0.025)
        }
        .rotationEffect(.degrees(-18))
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

#Preview("Vinyl appearances", traits: .sizeThatFitsLayout) {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            RecordDiscView(artSeed: 101, artStyle: .rings, initials: "GM")
                .frame(width: 160)
            RecordDiscView(artSeed: 110, artStyle: .beam, initials: "AS", appearance: .amber)
                .frame(width: 160)
        }
        HStack(spacing: 20) {
            RecordDiscView(artSeed: 106, artStyle: .rings, initials: "FE", appearance: .splatter)
                .frame(width: 160)
            RecordDiscView(artSeed: 109, artStyle: .missing, initials: "MT", titleText: "Ashline")
                .frame(width: 160)
        }
    }
    .padding(30)
    .background(Palette.stageGrey)
}
