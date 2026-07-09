import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Procedural vinyl dye, separated from the record's grooves, paper label, and lighting.
/// All geometry is seeded and normalized so the same pressing is stable at every size.
struct VinylSurfaceView: View {
    var style: VinylStyle
    var primary: Color
    var secondary: Color
    var seed: Int
    var size: CGFloat

    var body: some View {
        let detail = VinylRenderDetail(size: size)
        let palette = VinylDyePalette(primary: primary, secondary: secondary, seed: seed)

        ZStack {
            Circle()
                .fill(baseGradient(palette: palette))

            if style != .black {
                Canvas(opaque: false, rendersAsynchronously: true) { context, canvasSize in
                    VinylSurfaceRenderer.draw(
                        style: style,
                        seed: seed,
                        palette: palette,
                        detail: detail,
                        in: &context,
                        size: canvasSize
                    )
                }
            }

            materialDepth(palette: palette)
        }
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(Color.black.opacity(0.42), lineWidth: max(0.8, size * 0.006))
        )
    }

    private func baseGradient(palette: VinylDyePalette) -> RadialGradient {
        let colors: [Color]
        switch style {
        case .black:
            colors = [Color.white.opacity(0.08), Palette.vinylBlack, Palette.softBlack]
        case .translucent:
            colors = [palette.highlight.opacity(0.76), primary.opacity(0.68), palette.shadow.opacity(0.78)]
        case .halo:
            colors = [primary.opacity(0.88), palette.midpoint.opacity(0.94), palette.shadow.opacity(0.82)]
        case .smoke:
            colors = [palette.neutral.opacity(0.82), primary.opacity(0.86), palette.shadow.opacity(0.96)]
        case .splatterMix:
            colors = [
                palette.highlight.opacity(0.96),
                primary,
                VinylColorMixer.mix(primary, .black, amount: 0.12).opacity(0.90),
            ]
        default:
            colors = [palette.highlight.opacity(0.92), primary, palette.shadow.opacity(0.92)]
        }
        return RadialGradient(
            colors: colors,
            center: .center,
            startRadius: size * 0.03,
            endRadius: size * 0.54
        )
    }

    @ViewBuilder
    private func materialDepth(palette: VinylDyePalette) -> some View {
        if style == .translucent || style == .halo || style == .smoke {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(style == .translucent ? 0.13 : 0.07),
                            .clear,
                            palette.shadow.opacity(0.16),
                        ],
                        center: UnitPoint(x: 0.38, y: 0.30),
                        startRadius: 0,
                        endRadius: size * 0.56
                    )
                )
                .blendMode(.screen)
        } else if style == .burst {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            secondary.opacity(0.62),
                            secondary.opacity(0.34),
                            .clear,
                        ],
                        center: .center,
                        startRadius: size * 0.04,
                        endRadius: size * 0.25
                    )
                )
        }
    }
}

// MARK: - Public deterministic geometry hooks

/// Retained as a lightweight deterministic primitive for regression tests and callers.
struct VinylBlob: Equatable {
    var angle: Double
    var distance: Double
    var radius: Double
    var opacity: Double
}

/// Retained as a lightweight deterministic primitive for regression tests and callers.
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

struct VinylPatternSignature: Equatable {
    var componentCount: Int
    var definingSamples: [Int]
}

// MARK: - Renderer inputs

private struct VinylRenderDetail {
    var macroCount: Int
    var mesoCount: Int
    var microCount: Int
    var burstStreakCount: Int
    var splatterCount: Int
    var pathSamples: Int
    var blurScale: CGFloat

    init(size: CGFloat) {
        if size < 72 {
            macroCount = 4
            mesoCount = 7
            microCount = 0
            burstStreakCount = 18
            splatterCount = 16
            pathSamples = 12
            blurScale = 0.65
        } else if size < 180 {
            macroCount = 7
            mesoCount = 14
            microCount = 24
            burstStreakCount = 40
            splatterCount = 72
            pathSamples = 18
            blurScale = 0.82
        } else {
            macroCount = 10
            mesoCount = 24
            microCount = 58
            burstStreakCount = 60
            splatterCount = 144
            pathSamples = 26
            blurScale = 1
        }
    }
}

private struct VinylDyePalette {
    var primary: Color
    var secondary: Color
    var midpoint: Color
    var highlight: Color
    var neutral: Color
    var accent: Color
    var shadow: Color

    init(primary: Color, secondary: Color, seed: Int) {
        self.primary = primary
        self.secondary = secondary
        midpoint = VinylColorMixer.mix(primary, secondary, amount: 0.5)
        highlight = VinylColorMixer.mix(primary, .white, amount: 0.28)
        neutral = VinylColorMixer.mix(secondary, .white, amount: 0.68)
        let inkIndex = Int(seed.magnitude % UInt(Palette.labelInks.count))
        accent = Palette.labelInks[inkIndex]
        shadow = VinylColorMixer.mix(primary, .black, amount: 0.46)
    }

    func color(role: Int) -> Color {
        switch abs(role) % 6 {
        case 0: primary
        case 1: secondary
        case 2: accent
        case 3: midpoint
        case 4: highlight
        default: neutral
        }
    }
}

private enum VinylColorMixer {
    static func mix(_ first: Color, _ second: Color, amount: CGFloat) -> Color {
        #if canImport(UIKit)
        let a = rgba(first)
        let b = rgba(second)
        let t = min(max(amount, 0), 1)
        return Color(
            red: Double(a.red + (b.red - a.red) * t),
            green: Double(a.green + (b.green - a.green) * t),
            blue: Double(a.blue + (b.blue - a.blue) * t),
            opacity: Double(a.alpha + (b.alpha - a.alpha) * t)
        )
        #else
        return first
        #endif
    }

    #if canImport(UIKit)
    private static func rgba(_ color: Color) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return (0.5, 0.5, 0.5, 1)
        }
        return (red, green, blue, alpha)
    }
    #endif
}

private struct OrganicField {
    var center: CGPoint
    var radiusX: CGFloat
    var radiusY: CGFloat
    var rotation: Double
    var phase: Double
    var lobes: Int
    var roughness: CGFloat
    var opacity: Double
    var colorRole: Int
}

private struct DyeRibbon {
    var startAngle: Double
    var sweep: Double
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    var width: CGFloat
    var wave: Double
    var opacity: Double
    var colorRole: Int
}

private struct DyeSector {
    var startAngle: Double
    var width: Double
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    var bend: Double
    var opacity: Double
    var colorRole: Int
}

private struct DyeDrop {
    var center: CGPoint
    var radius: CGFloat
    var stretch: CGFloat
    var rotation: Double
    var phase: Double
    var opacity: Double
    var colorRole: Int
}

private enum VinylGeometryFactory {
    static func fields(seed: Int, count: Int, radial: Bool = false) -> [OrganicField] {
        var rng = SeededRandom(seed: seed &+ 1_701)
        return (0..<count).map { index in
            let angle = rng.double(in: 0...(2 * .pi))
            let distance = radial
                ? rng.double(in: 0.10...0.68)
                : rng.double(in: 0.06...0.82)
            let radius = rng.double(in: 0.15...0.34)
            return OrganicField(
                center: CGPoint(
                    x: 0.5 + cos(angle) * distance * 0.5,
                    y: 0.5 + sin(angle) * distance * 0.5
                ),
                radiusX: radius,
                radiusY: radius * rng.double(in: 0.48...1.12),
                rotation: angle + rng.double(in: -0.8...0.8),
                phase: rng.double(in: 0...(2 * .pi)),
                lobes: rng.int(in: 3...7),
                roughness: rng.double(in: 0.10...0.28),
                opacity: rng.double(in: 0.32...0.82),
                colorRole: index + rng.int(in: 0...3)
            )
        }
    }

    static func ribbons(seed: Int, count: Int, narrow: Bool = false) -> [DyeRibbon] {
        var rng = SeededRandom(seed: seed &+ 4_019)
        return (0..<count).map { index in
            DyeRibbon(
                startAngle: rng.double(in: 0...(2 * .pi)),
                sweep: rng.double(in: narrow ? 1.4...3.2 : 2.6...5.7),
                innerRadius: rng.double(in: 0.03...0.20),
                outerRadius: rng.double(in: 0.40...0.61),
                width: rng.double(in: narrow ? 0.008...0.025 : 0.045...0.13),
                wave: rng.double(in: 1.5...4.8),
                opacity: rng.double(in: narrow ? 0.18...0.42 : 0.30...0.74),
                colorRole: index + rng.int(in: 0...4)
            )
        }
    }

    static func sectors(seed: Int, count: Int, burst: Bool) -> [DyeSector] {
        var rng = SeededRandom(seed: seed &+ 8_191)
        let step = (2 * .pi) / Double(max(1, count))
        return (0..<count).map { index in
            let startAngle = burst
                ? rng.double(in: 0...(2 * .pi))
                : Double(index) * step + rng.double(in: -step * 0.16...step * 0.16)
            let width = burst
                ? rng.double(in: 0.018...0.10)
                : rng.double(in: step * 0.82...step * 1.12)
            return DyeSector(
                startAngle: startAngle,
                width: width,
                innerRadius: rng.double(in: burst ? 0.05...0.20 : 0.00...0.10),
                outerRadius: rng.double(in: 0.47...0.59),
                bend: rng.double(in: -0.26...0.26),
                opacity: rng.double(in: burst ? 0.36...0.82 : 0.62...0.94),
                colorRole: index
            )
        }
    }

    static func drops(
        seed: Int,
        count: Int,
        radial: Bool = false,
        fine: Bool = false
    ) -> [DyeDrop] {
        var rng = SeededRandom(seed: seed &+ 12_211)
        return (0..<count).map { index in
            let angle = rng.double(in: 0...(2 * .pi))
            let distance = sqrt(rng.double(in: 0.02...0.94)) * 0.47
            let radius = fine
                ? rng.double(in: 0.003...0.014)
                : rng.double(in: 0.006...0.034)
            return DyeDrop(
                center: CGPoint(
                    x: 0.5 + cos(angle) * distance,
                    y: 0.5 + sin(angle) * distance
                ),
                radius: radius,
                stretch: radial ? rng.double(in: 1.8...5.8) : rng.double(in: 0.72...1.75),
                rotation: radial ? angle : rng.double(in: 0...(2 * .pi)),
                phase: rng.double(in: 0...(2 * .pi)),
                opacity: rng.double(in: 0.38...0.91),
                colorRole: index + rng.int(in: 0...5)
            )
        }
    }
}

extension VinylPatternGeometry {
    static func signature(style: VinylStyle, seed: Int, size: CGFloat) -> VinylPatternSignature {
        let detail = VinylRenderDetail(size: size)

        switch style {
        case .black:
            return VinylPatternSignature(componentCount: 0, definingSamples: [])
        case .translucent:
            let fields = VinylGeometryFactory.fields(seed: seed, count: max(3, detail.macroCount / 2))
            return signature(fields: fields)
        case .swirl:
            let fields = VinylGeometryFactory.fields(
                seed: seed,
                count: min(8, detail.macroCount),
                radial: true
            )
            let ribbons = VinylGeometryFactory.ribbons(seed: seed &+ 31, count: detail.mesoCount)
            return signature(fields: fields, ribbons: ribbons)
        case .marble:
            let fields = VinylGeometryFactory.fields(seed: seed, count: detail.macroCount)
            let ribbons = VinylGeometryFactory.ribbons(
                seed: seed &+ 67,
                count: detail.mesoCount,
                narrow: true
            )
            return signature(fields: fields, ribbons: ribbons)
        case .pinwheel:
            let sectors = VinylGeometryFactory.sectors(seed: seed, count: 5, burst: false)
            let fields = VinylGeometryFactory.fields(
                seed: seed &+ 97,
                count: max(2, detail.macroCount / 2),
                radial: true
            )
            return signature(sectors: sectors, extraCount: fields.count)
        case .burst:
            let sectors = VinylGeometryFactory.sectors(
                seed: seed,
                count: detail.burstStreakCount,
                burst: true
            )
            let drops = VinylGeometryFactory.drops(
                seed: seed &+ 113,
                count: detail.microCount,
                radial: true
            )
            return signature(sectors: sectors, extraCount: drops.count)
        case .halo:
            let fields = VinylGeometryFactory.fields(
                seed: seed &+ 163,
                count: detail.mesoCount,
                radial: true
            )
            return signature(fields: fields, extraCount: 1)
        case .splatterMix:
            let drops = VinylGeometryFactory.drops(
                seed: seed,
                count: detail.splatterCount,
                radial: true,
                fine: true
            )
            return signature(drops: drops)
        case .smoke:
            let lightFields = VinylGeometryFactory.fields(
                seed: seed &+ 229,
                count: detail.macroCount + detail.mesoCount / 2
            )
            let shadowFields = VinylGeometryFactory.fields(
                seed: seed &+ 241,
                count: max(3, detail.macroCount / 2)
            )
            return signature(fields: lightFields + shadowFields)
        }
    }

    private static func signature(
        fields: [OrganicField] = [],
        ribbons: [DyeRibbon] = [],
        sectors: [DyeSector] = [],
        drops: [DyeDrop] = [],
        extraCount: Int = 0
    ) -> VinylPatternSignature {
        var samples: [Int] = []
        for field in fields.prefix(3) {
            samples.append(contentsOf: [
                quantize(field.center.x),
                quantize(field.center.y),
                quantize(field.radiusX),
                quantize(field.opacity),
            ])
        }
        for ribbon in ribbons.prefix(3) {
            samples.append(contentsOf: [
                quantize(ribbon.startAngle),
                quantize(ribbon.sweep),
                quantize(ribbon.width),
                quantize(ribbon.opacity),
            ])
        }
        for sector in sectors.prefix(3) {
            samples.append(contentsOf: [
                quantize(sector.startAngle),
                quantize(sector.width),
                quantize(sector.outerRadius),
                quantize(sector.opacity),
            ])
        }
        for drop in drops.prefix(3) {
            samples.append(contentsOf: [
                quantize(drop.center.x),
                quantize(drop.center.y),
                quantize(drop.radius),
                quantize(drop.opacity),
            ])
        }

        return VinylPatternSignature(
            componentCount: fields.count + ribbons.count + sectors.count + drops.count + extraCount,
            definingSamples: samples
        )
    }

    private static func quantize<T: BinaryFloatingPoint>(_ value: T) -> Int {
        Int((Double(value) * 10_000).rounded())
    }
}

// MARK: - Drawing

private enum VinylSurfaceRenderer {
    static func draw(
        style: VinylStyle,
        seed: Int,
        palette: VinylDyePalette,
        detail: VinylRenderDetail,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        switch style {
        case .black:
            break
        case .translucent:
            drawClearTint(seed: seed, palette: palette, detail: detail, context: &context, size: size)
        case .swirl:
            drawLiquidPour(seed: seed, palette: palette, detail: detail, context: &context, size: size)
        case .marble:
            drawVeinedMarble(seed: seed, palette: palette, detail: detail, context: &context, size: size)
        case .pinwheel:
            drawColorBlock(seed: seed, palette: palette, detail: detail, context: &context, size: size)
        case .burst:
            drawRadialBurst(seed: seed, palette: palette, detail: detail, context: &context, size: size)
        case .halo:
            drawFrostRing(seed: seed, palette: palette, detail: detail, context: &context, size: size)
        case .splatterMix:
            drawConfettiSplatter(seed: seed, palette: palette, detail: detail, context: &context, size: size)
        case .smoke:
            drawCloudySmoke(seed: seed, palette: palette, detail: detail, context: &context, size: size)
        }
    }

    private static func drawClearTint(
        seed: Int,
        palette: VinylDyePalette,
        detail: VinylRenderDetail,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let fields = VinylGeometryFactory.fields(seed: seed, count: max(3, detail.macroCount / 2))
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: size.width * 0.045 * detail.blurScale))
            layer.blendMode = .screen
            for field in fields {
                layer.fill(
                    organicPath(field, size: size, samples: detail.pathSamples),
                    with: .color(palette.highlight.opacity(field.opacity * 0.18))
                )
            }
        }

        let rim = Path(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.025, dy: size.height * 0.025))
        context.stroke(rim, with: .color(.white.opacity(0.22)), lineWidth: size.width * 0.018)
    }

    private static func drawLiquidPour(
        seed: Int,
        palette: VinylDyePalette,
        detail: VinylRenderDetail,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let fields = VinylGeometryFactory.fields(
            seed: seed,
            count: min(8, detail.macroCount),
            radial: true
        )
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: size.width * 0.018 * detail.blurScale))
            for field in fields {
                layer.fill(
                    organicPath(field, size: size, samples: detail.pathSamples),
                    with: .color(palette.color(role: field.colorRole).opacity(field.opacity * 0.88))
                )
            }
        }

        drawRibbons(
            VinylGeometryFactory.ribbons(seed: seed &+ 31, count: detail.mesoCount),
            palette: palette,
            detail: detail,
            context: &context,
            size: size,
            opacityScale: 0.62
        )
    }

    private static func drawVeinedMarble(
        seed: Int,
        palette: VinylDyePalette,
        detail: VinylRenderDetail,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let fields = VinylGeometryFactory.fields(seed: seed, count: detail.macroCount)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: size.width * 0.026 * detail.blurScale))
            for field in fields {
                layer.fill(
                    organicPath(field, size: size, samples: detail.pathSamples),
                    with: .color(palette.color(role: field.colorRole + 1).opacity(field.opacity * 0.72))
                )
            }
        }

        drawRibbons(
            VinylGeometryFactory.ribbons(seed: seed &+ 67, count: detail.mesoCount, narrow: true),
            palette: palette,
            detail: detail,
            context: &context,
            size: size,
            opacityScale: 0.9
        )
    }

    private static func drawColorBlock(
        seed: Int,
        palette: VinylDyePalette,
        detail: VinylRenderDetail,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let sectors = VinylGeometryFactory.sectors(seed: seed, count: 5, burst: false)
        for sector in sectors {
            context.fill(
                sectorPath(sector, size: size, samples: detail.pathSamples),
                with: .color(palette.color(role: sector.colorRole).opacity(sector.opacity))
            )
        }

        let softFields = VinylGeometryFactory.fields(seed: seed &+ 97, count: max(2, detail.macroCount / 2), radial: true)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: size.width * 0.022 * detail.blurScale))
            for field in softFields {
                layer.fill(
                    organicPath(field, size: size, samples: detail.pathSamples),
                    with: .color(palette.midpoint.opacity(field.opacity * 0.28))
                )
            }
        }
    }

    private static func drawRadialBurst(
        seed: Int,
        palette: VinylDyePalette,
        detail: VinylRenderDetail,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let sectors = VinylGeometryFactory.sectors(
            seed: seed,
            count: detail.burstStreakCount,
            burst: true
        )
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: size.width * 0.004 * detail.blurScale))
            for sector in sectors {
                layer.fill(
                    sectorPath(sector, size: size, samples: max(10, detail.pathSamples / 2)),
                    with: .color(palette.color(role: sector.colorRole + 1).opacity(sector.opacity * 0.82))
                )
            }
        }

        drawDrops(
            VinylGeometryFactory.drops(seed: seed &+ 113, count: detail.microCount, radial: true),
            palette: palette,
            detail: detail,
            context: &context,
            size: size,
            opacityScale: 0.74
        )
    }

    private static func drawFrostRing(
        seed: Int,
        palette: VinylDyePalette,
        detail: VinylRenderDetail,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        var rng = SeededRandom(seed: seed &+ 151)
        let phase = rng.double(in: 0...(2 * .pi))
        let ring = irregularRingPath(
            innerRadius: 0.20,
            outerRadius: 0.42,
            phase: phase,
            roughness: 0.035,
            samples: max(30, detail.pathSamples * 2),
            size: size
        )
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: size.width * 0.015 * detail.blurScale))
            layer.fill(ring, with: .color(palette.neutral.opacity(0.68)))
        }

        let fields = VinylGeometryFactory.fields(seed: seed &+ 163, count: detail.mesoCount, radial: true)
        for field in fields {
            let radius = hypot(field.center.x - 0.5, field.center.y - 0.5)
            guard radius > 0.19 && radius < 0.46 else { continue }
            context.fill(
                organicPath(field, size: size, samples: detail.pathSamples),
                with: .color(palette.highlight.opacity(field.opacity * 0.28))
            )
        }
    }

    private static func drawConfettiSplatter(
        seed: Int,
        palette: VinylDyePalette,
        detail: VinylRenderDetail,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        drawDrops(
            VinylGeometryFactory.drops(
                seed: seed,
                count: detail.splatterCount,
                radial: true,
                fine: true
            ),
            palette: palette,
            detail: detail,
            context: &context,
            size: size,
            opacityScale: 0.88
        )
    }

    private static func drawCloudySmoke(
        seed: Int,
        palette: VinylDyePalette,
        detail: VinylRenderDetail,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let fields = VinylGeometryFactory.fields(seed: seed &+ 229, count: detail.macroCount + detail.mesoCount / 2)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: size.width * 0.045 * detail.blurScale))
            for field in fields {
                let color = field.colorRole.isMultiple(of: 3) ? palette.neutral : palette.highlight
                layer.fill(
                    organicPath(field, size: size, samples: detail.pathSamples),
                    with: .color(color.opacity(field.opacity * 0.30))
                )
            }
        }

        let shadowFields = VinylGeometryFactory.fields(seed: seed &+ 241, count: max(3, detail.macroCount / 2))
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: size.width * 0.028 * detail.blurScale))
            for field in shadowFields {
                layer.fill(
                    organicPath(field, size: size, samples: detail.pathSamples),
                    with: .color(palette.shadow.opacity(field.opacity * 0.26))
                )
            }
        }
    }

    private static func drawRibbons(
        _ ribbons: [DyeRibbon],
        palette: VinylDyePalette,
        detail: VinylRenderDetail,
        context: inout GraphicsContext,
        size: CGSize,
        opacityScale: Double
    ) {
        for ribbon in ribbons {
            context.fill(
                ribbonPath(ribbon, size: size, samples: detail.pathSamples),
                with: .color(palette.color(role: ribbon.colorRole).opacity(ribbon.opacity * opacityScale))
            )
        }
    }

    private static func drawDrops(
        _ drops: [DyeDrop],
        palette: VinylDyePalette,
        detail: VinylRenderDetail,
        context: inout GraphicsContext,
        size: CGSize,
        opacityScale: Double
    ) {
        for drop in drops {
            context.fill(
                dropPath(drop, size: size, samples: max(10, detail.pathSamples / 2)),
                with: .color(palette.color(role: drop.colorRole).opacity(drop.opacity * opacityScale))
            )
        }
    }

    private static func organicPath(_ field: OrganicField, size: CGSize, samples: Int) -> Path {
        var points: [CGPoint] = []
        points.reserveCapacity(samples)
        let cosine = cos(field.rotation)
        let sine = sin(field.rotation)

        for index in 0..<samples {
            let angle = (Double(index) / Double(samples)) * 2 * .pi
            let variation = 1 + field.roughness * (
                0.62 * sin(Double(field.lobes) * angle + field.phase)
                + 0.38 * sin(Double(field.lobes + 3) * angle - field.phase * 0.7)
            )
            let localX = cos(angle) * field.radiusX * variation
            let localY = sin(angle) * field.radiusY * variation
            let x = field.center.x + localX * cosine - localY * sine
            let y = field.center.y + localX * sine + localY * cosine
            points.append(CGPoint(x: x * size.width, y: y * size.height))
        }
        return smoothClosedPath(points)
    }

    private static func ribbonPath(_ ribbon: DyeRibbon, size: CGSize, samples: Int) -> Path {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        var outer: [CGPoint] = []
        var inner: [CGPoint] = []
        outer.reserveCapacity(samples + 1)
        inner.reserveCapacity(samples + 1)

        for index in 0...samples {
            let t = Double(index) / Double(samples)
            let angle = ribbon.startAngle + ribbon.sweep * t
            let radius = ribbon.innerRadius + (ribbon.outerRadius - ribbon.innerRadius) * t
            let wobble = sin(t * .pi * ribbon.wave + ribbon.startAngle) * ribbon.width * 0.28
            outer.append(radialPoint(center: center, radius: radius + ribbon.width + wobble, angle: angle, size: size))
            inner.append(radialPoint(center: center, radius: max(0, radius - ribbon.width + wobble), angle: angle, size: size))
        }

        return smoothClosedPath(outer + inner.reversed())
    }

    private static func sectorPath(_ sector: DyeSector, size: CGSize, samples: Int) -> Path {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        var outer: [CGPoint] = []
        var inner: [CGPoint] = []
        outer.reserveCapacity(samples + 1)
        inner.reserveCapacity(samples + 1)

        for index in 0...samples {
            let t = Double(index) / Double(samples)
            let edgeWave = sin(t * .pi * 2 + sector.startAngle) * 0.014
            let angle = sector.startAngle + sector.width * t + sector.bend * sin(t * .pi)
            outer.append(radialPoint(center: center, radius: sector.outerRadius + edgeWave, angle: angle, size: size))
            inner.append(radialPoint(center: center, radius: max(0, sector.innerRadius - edgeWave * 0.45), angle: angle, size: size))
        }
        return smoothClosedPath(outer + inner.reversed())
    }

    private static func dropPath(_ drop: DyeDrop, size: CGSize, samples: Int) -> Path {
        let field = OrganicField(
            center: drop.center,
            radiusX: drop.radius * drop.stretch,
            radiusY: drop.radius,
            rotation: drop.rotation,
            phase: drop.phase,
            lobes: 4,
            roughness: 0.22,
            opacity: drop.opacity,
            colorRole: drop.colorRole
        )
        return organicPath(field, size: size, samples: samples)
    }

    private static func irregularRingPath(
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        phase: Double,
        roughness: CGFloat,
        samples: Int,
        size: CGSize
    ) -> Path {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        var outer: [CGPoint] = []
        var inner: [CGPoint] = []
        outer.reserveCapacity(samples)
        inner.reserveCapacity(samples)

        for index in 0..<samples {
            let angle = (Double(index) / Double(samples)) * 2 * .pi
            let outerWave = roughness * (sin(angle * 7 + phase) + 0.45 * sin(angle * 13 - phase))
            let innerWave = roughness * (sin(angle * 5 - phase) + 0.38 * sin(angle * 11 + phase))
            outer.append(radialPoint(center: center, radius: outerRadius + outerWave, angle: angle, size: size))
            inner.append(radialPoint(center: center, radius: innerRadius + innerWave, angle: angle, size: size))
        }

        var path = smoothClosedPath(outer)
        path.addPath(smoothClosedPath(inner.reversed()))
        return path
    }

    private static func radialPoint(center: CGPoint, radius: CGFloat, angle: Double, size: CGSize) -> CGPoint {
        CGPoint(
            x: center.x + cos(angle) * radius * size.width,
            y: center.y + sin(angle) * radius * size.height
        )
    }

    private static func smoothClosedPath<S: Sequence>(_ sequence: S) -> Path where S.Element == CGPoint {
        let points = Array(sequence)
        guard points.count > 2 else { return Path() }

        var path = Path()
        path.move(to: midpoint(points[points.count - 1], points[0]))
        for index in points.indices {
            let point = points[index]
            let next = points[(index + 1) % points.count]
            path.addQuadCurve(to: midpoint(point, next), control: point)
        }
        path.closeSubpath()
        return path
    }

    private static func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) * 0.5, y: (first.y + second.y) * 0.5)
    }
}
