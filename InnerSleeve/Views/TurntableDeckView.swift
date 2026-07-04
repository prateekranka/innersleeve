import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The fixed, product-rendered turntable deck. Pure illustration — no glass.
/// Off-white body, recessed platter, engraved details, amber status display.
struct TurntableDeckView: View {
    var displayText: String
    var onStop: (() -> Void)? = nil
    var isPlaying: Bool = false

    var body: some View {
        ZStack {
            body_
            platterRecess
            vents
            brandMark
            armRestClip
            statusDisplay
            DeckStopButton(onStop: onStop, isPlaying: isPlaying)
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
            Circle()
                .fill(Palette.metalGrey)
                .overlay(
                    Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                )
                .frame(width: 158, height: 158)
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.8)
                    .frame(width: 140 - CGFloat(i) * 26, height: 140 - CGFloat(i) * 26)
            }
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

    /// Small metal clip at the resting tonearm tip position (angle -16°).
    private var armRestClip: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.82, green: 0.82, blue: 0.80), Color(red: 0.60, green: 0.60, blue: 0.58)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 10, height: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.18), lineWidth: 0.6)
            )
            .offset(x: 10, y: 52)
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
            .offset(x: 0, y: 94)
    }
}

// MARK: - Deck hardware controls

/// Off-white bevel key cap stop button with amber LED indicator.
private struct DeckStopButton: View {
    var onStop: (() -> Void)?
    var isPlaying: Bool

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 6) {
            Button {
                onStop?()
            } label: {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isPressed
                                ? [Color(red: 0.84, green: 0.83, blue: 0.81), Color(red: 0.77, green: 0.76, blue: 0.74)]
                                : [Palette.offWhite, Color(red: 0.88, green: 0.87, blue: 0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 48, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.8), .black.opacity(0.18)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.55))
                    )
                    .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
            .sensoryFeedback(.impact(weight: .medium), trigger: isPressed)
            .accessibilityLabel("Stop")

            Circle()
                .fill(isPlaying ? Palette.amberDisplay : Palette.amberDisplay.opacity(0.15))
                .frame(width: 5, height: 5)
                .shadow(color: isPlaying ? Palette.amberDisplay.opacity(0.6) : .clear, radius: 3)
        }
        .offset(x: 128, y: 90)
    }
}

// MARK: - Ticker display

private struct DeckTickerDisplay: View {
    var text: String

    @State private var startDate = Date()

    private let displayWidth: CGFloat = 300
    private let scrollSpeed: CGFloat = 30
    private let gapText = "     •     "
    private let font = UIFont.monospacedSystemFont(ofSize: 8.5, weight: .medium)

    private var measuredWidth: CGFloat {
        let display = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !display.isEmpty else { return 0 }
        return (display as NSString).size(withAttributes: [.font: font]).width
    }

    private var gapWidth: CGFloat {
        (gapText as NSString).size(withAttributes: [.font: font]).width
    }

    var body: some View {
        let displayText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldScroll = !displayText.isEmpty
            && displayText != "No record on deck"
            && displayText != "Queue empty"

        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !shouldScroll)) { context in
            let repeatedText = shouldScroll ? "\(displayText)\(gapText)\(displayText)" : displayText
            let singleTravel = max(measuredWidth, displayWidth) + gapWidth
            let cycle = singleTravel / scrollSpeed
            let elapsed = max(0, context.date.timeIntervalSince(startDate) - 1.0)
            let progress = shouldScroll ? elapsed.truncatingRemainder(dividingBy: cycle) / cycle : 0

            Text(repeatedText)
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .kerning(0.6)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(Palette.amberDisplay)
                .offset(x: shouldScroll ? -singleTravel * progress : 0)
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

// MARK: - Tonearm

/// The white tonearm — rendered as its own layer so it can lift and drop.
/// Rotates around its pivot base through the given angle in degrees.
struct TonearmView: View {
    var angle: Double = -16
    var isLifted: Bool = false
    private var isGrooveRiding: Bool = false

    @State private var grooveRideStartedAt: Date?

    private let pivotAnchor = UnitPoint(x: 0.69, y: 0.09)

    init(angle: Double = -16, isLifted: Bool = false, isGrooveRiding: Bool = false) {
        self.angle = angle
        self.isLifted = isLifted
        self.isGrooveRiding = isGrooveRiding
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isGrooveRiding)) { context in
            let playbackTime = grooveRideStartedAt.map { max(0, context.date.timeIntervalSince($0)) } ?? 0
            let motion = TonearmPlaybackMotion.values(
                playbackTime: playbackTime,
                isPlaying: isGrooveRiding && !isLifted
            )

            ZStack {
                pivotBase
                armAndHeadshell(motion: motion)
            }
        }
        .rotationEffect(.degrees(angle), anchor: pivotAnchor)
        .offset(y: isLifted ? -4 : 0)
        .animation(.spring(response: 0.42, dampingFraction: 0.7), value: angle)
        .animation(.spring(response: 0.42, dampingFraction: 0.7), value: isLifted)
        .frame(width: 344, height: 236)
        .contentShape(TonearmHitShape())
        .onAppear {
            grooveRideStartedAt = isGrooveRiding ? Date() : nil
        }
        .onChange(of: isGrooveRiding) { _, isActive in
            grooveRideStartedAt = isActive ? Date() : nil
        }
    }

    func grooveRiding(_ isGrooveRiding: Bool) -> TonearmView {
        var copy = self
        copy.isGrooveRiding = isGrooveRiding
        return copy
    }

    private var pivotBase: some View {
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
    }

    private var arm: some View {
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
    }

    private func armAndHeadshell(motion: TonearmPlaybackMotion) -> some View {
        ZStack {
            arm
            headshell
                .rotationEffect(
                    .degrees(motion.headshellRotationDegrees),
                    anchor: UnitPoint(x: 0.5, y: 0.1)
                )
        }
        .offset(y: CGFloat(motion.verticalOffset))
    }

    private var headshell: some View {
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

    private struct TonearmHitShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let pivot = CGPoint(x: rect.midX + 66, y: rect.midY - 96)
            let elbow = CGPoint(x: rect.midX + 44, y: rect.midY + 6)
            let tip = CGPoint(x: rect.midX - 24, y: rect.midY + 40)
            let radius: CGFloat = 13
            let tipRadius: CGFloat = 11

            path.move(to: CGPoint(x: pivot.x - radius, y: pivot.y - radius))
            path.addLine(to: CGPoint(x: pivot.x + radius, y: pivot.y - radius))
            path.addLine(to: CGPoint(x: elbow.x + radius, y: elbow.y))
            path.addLine(to: CGPoint(x: tip.x + tipRadius, y: tip.y + tipRadius))
            path.addLine(to: CGPoint(x: tip.x - tipRadius, y: tip.y + tipRadius))
            path.addLine(to: CGPoint(x: elbow.x - radius, y: elbow.y))
            path.closeSubpath()
            return path
        }
    }
}

#Preview("Deck with tonearm", traits: .sizeThatFitsLayout) {
    ZStack {
        TurntableDeckView(displayText: "Now Playing · Night Bureau", isPlaying: true)
        TonearmView(angle: 0, isLifted: false)
    }
    .padding(40)
    .background(Palette.stageGrey)
}

#Preview("Deck · resting arm", traits: .sizeThatFitsLayout) {
    ZStack {
        TurntableDeckView(displayText: "Queue empty", isPlaying: false)
        TonearmView(angle: -16, isLifted: false)
    }
    .padding(40)
    .background(Palette.stageGrey)
}
