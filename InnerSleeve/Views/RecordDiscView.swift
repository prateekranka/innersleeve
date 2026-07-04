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
                grooves(size: size)
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

struct VinylBlob: Equatable {
    var angle: Double
    var distance: Double
    var radius: Double
    var opacity: Double
}

struct VinylRay: Equatable {
    var startAngle: Double
    var width: Double
    var opacity: Double
}

enum VinylPatternGeometry {
    static func blobs(seed: Int, count: Int) -> [VinylBlob] {
        var rng = SeededRandom(seed: seed &+ 991)
        return (0..<count).map { _ in
            VinylBlob(
                angle: rng.double(in: 0...(2 * .pi)),
                distance: rng.double(in: 0.16...0.98),
                radius: rng.double(in: 0.008...0.034),
                opacity: rng.double(in: 0.38...0.86)
            )
        }
    }

    static func rays(seed: Int, count: Int) -> [VinylRay] {
        var rng = SeededRandom(seed: seed &+ 311)
        let step = (2 * .pi) / Double(max(count, 1))
        return (0..<count).map { index in
            VinylRay(
                startAngle: Double(index) * step + rng.double(in: -0.08...0.08),
                width: rng.double(in: step * 0.38...step * 0.72),
                opacity: rng.double(in: 0.35...0.72)
            )
        }
    }
}

struct VinylSurfaceView: View {
    var style: VinylStyle
    var primary: Color
    var secondary: Color
    var seed: Int
    var size: CGFloat

    var body: some View {
        ZStack {
            base
            pattern
        }
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.black.opacity(0.42), lineWidth: max(0.8, size * 0.006)))
    }

    private var base: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: baseColors,
                    center: .center,
                    startRadius: size * 0.05,
                    endRadius: size * 0.52
                )
            )
    }

    private var baseColors: [Color] {
        switch style {
        case .black:
            return [Color.white.opacity(0.08), Palette.vinylBlack, Palette.softBlack]
        case .translucent:
            return [primary.opacity(0.78), primary.opacity(0.52), secondary.opacity(0.82)]
        case .smoke:
            return [primary.opacity(0.82), secondary.opacity(0.95), Palette.vinylBlack]
        case .marble:
            return [primary.opacity(0.95), secondary.opacity(0.55), primary.opacity(0.72)]
        default:
            return [primary.opacity(0.94), Palette.vinylBlack.opacity(0.9), secondary.opacity(0.86)]
        }
    }

    @ViewBuilder
    private var pattern: some View {
        switch style {
        case .black:
            EmptyView()
        case .translucent:
            translucentVeil
        case .swirl:
            swirlCanvas
        case .marble:
            marbleCanvas
        case .pinwheel:
            rayCanvas(rayCount: 12, innerCutout: 0.15)
        case .burst:
            rayCanvas(rayCount: 28, innerCutout: 0.08)
        case .halo:
            halo
        case .splatterMix:
            splatterCanvas
        case .smoke:
            smokeCanvas
        }
    }

    private var translucentVeil: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: size * 0.12)
                .blur(radius: size * 0.02)
            Circle()
                .fill(primary.opacity(0.14))
                .padding(size * 0.08)
        }
    }

    private var halo: some View {
        ZStack {
            Circle()
                .strokeBorder(secondary.opacity(0.54), lineWidth: size * 0.16)
                .padding(size * 0.12)
                .blur(radius: size * 0.012)
            Circle()
                .strokeBorder(primary.opacity(0.22), lineWidth: size * 0.08)
                .padding(size * 0.29)
        }
    }

    private var swirlCanvas: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let outer = canvasSize.width * 0.54
            for index in 0..<7 {
                var path = Path()
                let offset = Double(index) * 0.9 + Double(seed % 19) * 0.03
                for step in 0...160 {
                    let t = Double(step) / 160.0
                    let angle = offset + t * 5.9
                    let radius = outer * CGFloat(0.12 + t * 0.84)
                    let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                    if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                context.stroke(path, with: .color((index.isMultiple(of: 2) ? secondary : primary).opacity(0.34)), lineWidth: size * 0.07)
            }
        }
    }

    private var marbleCanvas: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let outer = canvasSize.width * 0.47
            let blobs = VinylPatternGeometry.blobs(seed: seed, count: 18)
            for (index, blob) in blobs.enumerated() {
                let x = center.x + cos(blob.angle) * outer * blob.distance
                let y = center.y + sin(blob.angle) * outer * blob.distance
                let radius = outer * CGFloat(blob.radius * 4.8)
                let rect = CGRect(x: x - radius, y: y - radius * 0.45, width: radius * 2.4, height: radius * 0.9)
                let path = Path(ellipseIn: rect)
                context.fill(path, with: .color((index.isMultiple(of: 2) ? secondary : Color.black).opacity(blob.opacity * 0.22)))
            }
        }
        .blur(radius: size * 0.01)
    }

    private func rayCanvas(rayCount: Int, innerCutout: CGFloat) -> some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let outer = canvasSize.width * 0.55
            let inner = canvasSize.width * innerCutout
            for (index, ray) in VinylPatternGeometry.rays(seed: seed, count: rayCount).enumerated() {
                var path = Path()
                path.move(to: CGPoint(
                    x: center.x + cos(ray.startAngle) * inner,
                    y: center.y + sin(ray.startAngle) * inner
                ))
                path.addLine(to: CGPoint(
                    x: center.x + cos(ray.startAngle) * outer,
                    y: center.y + sin(ray.startAngle) * outer
                ))
                path.addArc(
                    center: center,
                    radius: outer,
                    startAngle: .radians(ray.startAngle),
                    endAngle: .radians(ray.startAngle + ray.width),
                    clockwise: false
                )
                path.addLine(to: CGPoint(
                    x: center.x + cos(ray.startAngle + ray.width) * inner,
                    y: center.y + sin(ray.startAngle + ray.width) * inner
                ))
                path.addArc(
                    center: center,
                    radius: inner,
                    startAngle: .radians(ray.startAngle + ray.width),
                    endAngle: .radians(ray.startAngle),
                    clockwise: true
                )
                context.fill(path, with: .color((index.isMultiple(of: 2) ? secondary : primary).opacity(ray.opacity)))
            }
        }
    }

    private var splatterCanvas: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let outer = canvasSize.width * 0.47
            for (index, blob) in VinylPatternGeometry.blobs(seed: seed, count: 78).enumerated() {
                let radius = canvasSize.width * CGFloat(blob.radius)
                let x = center.x + cos(blob.angle) * outer * blob.distance
                let y = center.y + sin(blob.angle) * outer * blob.distance
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                    with: .color((index.isMultiple(of: 3) ? Palette.warmYellow : secondary).opacity(blob.opacity))
                )
            }
        }
    }

    private var smokeCanvas: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let outer = canvasSize.width * 0.46
            for (index, blob) in VinylPatternGeometry.blobs(seed: seed &+ 17, count: 24).enumerated() {
                let radius = outer * CGFloat(blob.radius * 5.2)
                let x = center.x + cos(blob.angle) * outer * blob.distance * 0.9
                let y = center.y + sin(blob.angle) * outer * blob.distance * 0.9
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius * 0.55, width: radius * 2.4, height: radius * 1.1)),
                    with: .color((index.isMultiple(of: 2) ? Color.white : primary).opacity(blob.opacity * 0.18))
                )
            }
        }
        .blur(radius: size * 0.018)
    }
}

#Preview("Vinyl appearances", traits: .sizeThatFitsLayout) {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            RecordDiscView(artSeed: 101, artStyle: .rings, initials: "GM")
                .frame(width: 160)
            RecordDiscView(artSeed: 110, artStyle: .beam, initials: "AS", vinylStyle: .translucent)
                .frame(width: 160)
        }
        HStack(spacing: 20) {
            RecordDiscView(artSeed: 106, artStyle: .rings, initials: "FE", vinylStyle: .splatterMix)
                .frame(width: 160)
            RecordDiscView(artSeed: 109, artStyle: .missing, initials: "MT", titleText: "Ashline", vinylStyle: .swirl)
                .frame(width: 160)
        }
    }
    .padding(30)
    .background(Palette.stageGrey)
}
