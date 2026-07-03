import SwiftUI

/// The fixed, product-rendered turntable deck. Pure illustration — no glass.
/// Off-white body, recessed platter, engraved details, amber status display.
struct TurntableDeckView: View {
    var displayText: String
    var stylusCueProgress: Double? = nil

    var body: some View {
        ZStack {
            body_
            platterRecess
            vents
            brandMark
            statusDisplay
            if let progress = stylusCueProgress {
                stylusCueIndicator(progress: progress)
            }
        }
        .frame(width: deckWidth, height: deckHeight)
    }

    private let deckWidth: CGFloat = 344
    private let deckHeight: CGFloat = 236

    // MARK: Body shell

    private var body_: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Palette.offWhite,
                        Color(red: 0.90, green: 0.89, blue: 0.87),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                // Bevel: light top edge, dark bottom edge.
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.9), .black.opacity(0.14)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Palette.warmShadow, radius: 24, y: 16)
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    // MARK: Platter

    private var platterRecess: some View {
        ZStack {
            // Recess ring (inner shadow feel).
            Circle()
                .fill(Color(red: 0.84, green: 0.83, blue: 0.81))
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [.black.opacity(0.18), .white.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                )
                .frame(width: 178, height: 178)
            // Platter mat.
            Circle()
                .fill(Palette.metalGrey)
                .overlay(
                    Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                )
                .frame(width: 158, height: 158)
            // Machined concentric marks.
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.8)
                    .frame(width: 140 - CGFloat(i) * 26, height: 140 - CGFloat(i) * 26)
            }
            // Spindle.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.85, green: 0.85, blue: 0.84), Color(red: 0.55, green: 0.55, blue: 0.54)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 9, height: 9)
                .shadow(color: .black.opacity(0.4), radius: 1, y: 0.5)
        }
        .offset(x: -52, y: 0)
    }

    // MARK: Details

    private var vents: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { _ in
                Capsule()
                    .fill(Color.black.opacity(0.14))
                    .frame(width: 3, height: 16)
            }
        }
        .offset(x: 122, y: -92)
    }

    private var brandMark: some View {
        Text("INNER SLEEVE · IS-1")
            .font(.system(size: 7, weight: .semibold, design: .monospaced))
            .kerning(1.2)
            .foregroundStyle(Color.black.opacity(0.35))
            .offset(x: -108, y: -100)
    }

    private var statusDisplay: some View {
        DeckTickerDisplay(text: displayText)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
            )
            .offset(x: 62, y: 92)
    }

    /// A small amber dot drawn on the platter at a radial position matching
    /// the stylus cue progress (0 = outer edge, 1 = spindle).
    private func stylusCueIndicator(progress: Double) -> some View {
        let platterRadius: CGFloat = 79
        let clamped = min(max(progress, 0), 1)
        let distance = (1 - clamped) * platterRadius
        return Circle()
            .fill(Palette.amberDisplay)
            .frame(width: 6, height: 6)
            .shadow(color: Palette.amberDisplay.opacity(0.6), radius: 4)
            .offset(x: -52, y: distance)
    }
}

private struct DeckTickerDisplay: View {
    var text: String

    @State private var startDate = Date()

    private let displayWidth: CGFloat = 190
    private let characterThreshold = 22

    var body: some View {
        let displayText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldScroll = displayText.count > characterThreshold

        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !shouldScroll)) { context in
            let repeatedText = shouldScroll ? "\(displayText)     •     \(displayText)" : displayText
            let travel = max(0, CGFloat(displayText.count - characterThreshold) * 6 + 42)
            let cycle = max(5.5, Double(displayText.count) * 0.18)
            let elapsed = max(0, context.date.timeIntervalSince(startDate) - 1.0)
            let progress = shouldScroll ? elapsed.truncatingRemainder(dividingBy: cycle) / cycle : 0

            Text(repeatedText)
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .kerning(0.6)
                .lineLimit(1)
                .foregroundStyle(Palette.amberDisplay)
                .offset(x: shouldScroll ? -travel * progress : 0)
                .frame(width: displayWidth, alignment: .leading)
                .id(displayText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: displayWidth, alignment: .leading)
        .clipped()
        .onAppear {
            startDate = Date()
        }
        .onChange(of: text) {
            startDate = Date()
        }
    }
}

/// The white tonearm — rendered as its own layer so it can lift and drop.
struct TonearmView: View {
    /// True while a record change is in flight; lifts the arm.
    var isLifted: Bool

    var body: some View {
        ZStack {
            // Pivot base.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.82, green: 0.82, blue: 0.80)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 34, height: 34)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
                .offset(x: 66, y: -96)

            // Arm.
            ArmShape()
                .stroke(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.88, green: 0.88, blue: 0.86)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .shadow(color: .black.opacity(isLifted ? 0.32 : 0.20), radius: isLifted ? 9 : 4, y: isLifted ? 10 : 4)

            // Headshell.
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.white)
                .frame(width: 15, height: 26)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.14), lineWidth: 0.8)
                )
                .rotationEffect(.degrees(24))
                .offset(x: -22, y: 44)
                .shadow(color: .black.opacity(0.18), radius: 2, y: 2)
        }
        .rotationEffect(.degrees(isLifted ? -7 : 0), anchor: UnitPoint(x: 0.69, y: 0.09))
        .offset(y: isLifted ? -4 : 0)
        .animation(.spring(response: 0.42, dampingFraction: 0.7), value: isLifted)
        .frame(width: 344, height: 236)
        .allowsHitTesting(false)
    }

    /// The bent arm path: pivot at top-right, sweeping down-left over the platter.
    private struct ArmShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let pivot = CGPoint(x: rect.midX + 66, y: rect.midY - 96)
            let elbow = CGPoint(x: rect.midX + 44, y: rect.midY + 6)
            let tip = CGPoint(x: rect.midX - 24, y: rect.midY + 40)
            path.move(to: pivot)
            path.addLine(to: elbow)
            path.addQuadCurve(to: tip, control: CGPoint(x: rect.midX + 34, y: rect.midY + 48))
            return path
        }
    }
}

#Preview("Deck with tonearm", traits: .sizeThatFitsLayout) {
    ZStack {
        TurntableDeckView(displayText: "Now Playing · Night Bureau")
        TonearmView(isLifted: false)
    }
    .padding(40)
    .background(Palette.stageGrey)
}
