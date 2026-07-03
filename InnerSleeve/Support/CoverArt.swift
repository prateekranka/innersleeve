import SwiftUI

/// Generative label-art styles. Every record gets deterministic art from its seed.
enum CoverArtStyle: String, Codable, CaseIterable {
    case rings
    case quadrants
    case wave
    case dots
    case beam
    case missing
}

/// Procedurally generated cover/label art drawn with Canvas.
/// Deterministic for a given (seed, style) pair, so previews and
/// screenshots are stable.
struct CoverArtView: View {
    var seed: Int
    var style: CoverArtStyle
    var initials: String
    var titleText: String = ""

    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: seed)
            let rect = CGRect(origin: .zero, size: size)

            switch style {
            case .missing:
                drawMissing(context: context, rect: rect)
            case .rings:
                drawRings(context: context, rect: rect, rng: &rng)
            case .quadrants:
                drawQuadrants(context: context, rect: rect, rng: &rng)
            case .wave:
                drawWave(context: context, rect: rect, rng: &rng)
            case .dots:
                drawDots(context: context, rect: rect, rng: &rng)
            case .beam:
                drawBeam(context: context, rect: rect, rng: &rng)
            }
        }
    }

    // MARK: Styles

    private func drawMissing(context: GraphicsContext, rect: CGRect) {
        context.fill(Path(rect), with: .color(Palette.offWhite))
        let inset = rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06)
        context.stroke(
            Path(inset),
            with: .color(Palette.inkOnStage.opacity(0.35)),
            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
        )
        let center = CGPoint(x: rect.midX, y: rect.midY - rect.height * 0.06)
        context.draw(
            Text(initials)
                .font(.system(size: rect.width * 0.30, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.inkOnStage.opacity(0.75)),
            at: center
        )
        if !titleText.isEmpty {
            context.draw(
                Text(titleText.uppercased())
                    .font(.system(size: max(6, rect.width * 0.07), weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.inkOnStage.opacity(0.5)),
                at: CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.24)
            )
        }
    }

    private func drawRings(context: GraphicsContext, rect: CGRect, rng: inout SeededRandom) {
        let paper = rng.pick(Palette.labelPapers)
        context.fill(Path(rect), with: .color(paper))
        let inkA = rng.pick(Palette.labelInks)
        let inkB = rng.pick(Palette.labelInks)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let count = rng.int(in: 5...9)
        let maxR = rect.width * 0.62
        for i in 0..<count {
            let t = Double(i) / Double(max(count - 1, 1))
            let radius = maxR * (0.18 + 0.82 * t)
            let ring = Path(ellipseIn: CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            ))
            let ink = i.isMultiple(of: 2) ? inkA : inkB
            context.stroke(ring, with: .color(ink.opacity(0.9 - t * 0.35)), lineWidth: rect.width * rng.double(in: 0.018...0.05))
        }
        drawInitials(context: context, rect: rect, on: paper)
    }

    private func drawQuadrants(context: GraphicsContext, rect: CGRect, rng: inout SeededRandom) {
        let paper = rng.pick(Palette.labelPapers)
        context.fill(Path(rect), with: .color(paper))
        let cols = rng.int(in: 2...3)
        let rows = rng.int(in: 2...3)
        let w = rect.width / CGFloat(cols)
        let h = rect.height / CGFloat(rows)
        for c in 0..<cols {
            for r in 0..<rows {
                guard rng.double(in: 0...1) > 0.25 else { continue }
                let cell = CGRect(x: CGFloat(c) * w, y: CGFloat(r) * h, width: w, height: h)
                    .insetBy(dx: w * 0.06, dy: h * 0.06)
                let ink = rng.pick(Palette.labelInks)
                if rng.double(in: 0...1) > 0.5 {
                    context.fill(Path(ellipseIn: cell), with: .color(ink.opacity(0.85)))
                } else {
                    context.fill(Path(cell), with: .color(ink.opacity(0.85)))
                }
            }
        }
        drawInitials(context: context, rect: rect, on: paper)
    }

    private func drawWave(context: GraphicsContext, rect: CGRect, rng: inout SeededRandom) {
        let paper = rng.pick(Palette.labelPapers)
        context.fill(Path(rect), with: .color(paper))
        let lines = rng.int(in: 6...10)
        let amplitude = rect.height * rng.double(in: 0.03...0.07)
        let frequency = rng.double(in: 1.5...3.5)
        let ink = rng.pick(Palette.labelInks)
        for i in 0..<lines {
            let baseY = rect.height * (0.12 + 0.76 * Double(i) / Double(max(lines - 1, 1)))
            var path = Path()
            path.move(to: CGPoint(x: 0, y: baseY))
            let steps = 40
            for s in 1...steps {
                let x = rect.width * CGFloat(s) / CGFloat(steps)
                let phase = Double(i) * 0.7
                let y = baseY + CGFloat(sin(Double(s) / Double(steps) * .pi * 2 * frequency + phase)) * amplitude
                path.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(path, with: .color(ink.opacity(0.9 - Double(i) * 0.05)), lineWidth: rect.height * 0.018)
        }
        drawInitials(context: context, rect: rect, on: paper)
    }

    private func drawDots(context: GraphicsContext, rect: CGRect, rng: inout SeededRandom) {
        let paper = rng.pick(Palette.labelPapers)
        context.fill(Path(rect), with: .color(paper))
        let inkA = rng.pick(Palette.labelInks)
        let inkB = rng.pick(Palette.labelInks)
        let grid = rng.int(in: 5...8)
        let cell = rect.width / CGFloat(grid)
        for c in 0..<grid {
            for r in 0..<grid {
                let radius = cell * rng.double(in: 0.10...0.42)
                let cx = cell * (CGFloat(c) + 0.5)
                let cy = cell * (CGFloat(r) + 0.5)
                let ink = (c + r).isMultiple(of: 2) ? inkA : inkB
                context.fill(
                    Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)),
                    with: .color(ink.opacity(rng.double(in: 0.55...0.95)))
                )
            }
        }
        drawInitials(context: context, rect: rect, on: paper)
    }

    private func drawBeam(context: GraphicsContext, rect: CGRect, rng: inout SeededRandom) {
        let paper = rng.pick(Palette.labelPapers)
        context.fill(Path(rect), with: .color(paper))
        let bands = rng.int(in: 4...7)
        var x: CGFloat = 0
        for _ in 0..<bands {
            let width = rect.width * rng.double(in: 0.08...0.28)
            let ink = rng.pick(Palette.labelInks)
            let band = CGRect(x: x, y: 0, width: width, height: rect.height)
            var ctx = context
            ctx.rotate(by: .degrees(rng.double(in: -4...4)))
            ctx.fill(Path(band), with: .color(ink.opacity(rng.double(in: 0.6...0.95))))
            x += width * rng.double(in: 0.8...1.4)
            if x > rect.width { break }
        }
        drawInitials(context: context, rect: rect, on: paper)
    }

    private func drawInitials(context: GraphicsContext, rect: CGRect, on paper: Color) {
        // Small pressed-label monogram in the middle, like a stamped matrix code.
        let dark = paper == Palette.labelPapers[2] || paper == Palette.labelPapers[4]
        let ink: Color = dark ? Palette.offWhite : Palette.inkOnStage
        let chipSize = CGSize(width: rect.width * 0.34, height: rect.height * 0.18)
        let chipRect = CGRect(
            x: rect.midX - chipSize.width / 2,
            y: rect.midY - chipSize.height / 2,
            width: chipSize.width,
            height: chipSize.height
        )
        context.fill(
            Path(roundedRect: chipRect, cornerRadius: chipSize.height * 0.2),
            with: .color((dark ? Color.black : Palette.offWhite).opacity(0.65))
        )
        context.draw(
            Text(initials)
                .font(.system(size: chipSize.height * 0.62, weight: .bold, design: .monospaced))
                .foregroundStyle(ink.opacity(0.9)),
            at: CGPoint(x: rect.midX, y: rect.midY)
        )
    }
}

extension String {
    /// "Glass Meridian" -> "GM"
    var artInitials: String {
        split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }
}

#Preview("Cover art styles", traits: .sizeThatFitsLayout) {
    let styles: [CoverArtStyle] = [.rings, .quadrants, .wave, .dots, .beam, .missing]
    return LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
        ForEach(Array(styles.enumerated()), id: \.offset) { index, style in
            CoverArtView(seed: 40 + index, style: style, initials: "GM", titleText: "Night Bureau")
                .frame(width: 100, height: 100)
                .clipShape(Circle())
        }
    }
    .padding()
    .background(Palette.stageGrey)
}
