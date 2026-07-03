import SwiftUI

enum SleevePullMath {
    static let threshold: CGFloat = 0.62
    static let pullDistance: CGFloat = 190
    static let baseRecordOffset: CGFloat = 74
    static let revealedTravel: CGFloat = 120

    static func progress(for translationWidth: CGFloat) -> CGFloat {
        min(max(translationWidth / pullDistance, 0), 1)
    }

    static func recordOffset(progress: CGFloat) -> CGFloat {
        baseRecordOffset + min(max(progress, 0), 1) * revealedTravel
    }

    static func crossedThreshold(previous: CGFloat, current: CGFloat) -> Bool {
        previous < threshold && current >= threshold
    }

    static func resolvesRevealed(progress: CGFloat) -> Bool {
        progress >= threshold
    }
}

struct SleevePullView: View {
    var record: Record

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pullProgress: CGFloat = 0
    @State private var revealed = false
    @State private var thresholdPulse = 0
    @State private var fanCount = 0
    @State private var inspecting: PackageAttachment? = nil
    @State private var idlePeek: CGFloat = 0

    private var attachments: [PackageAttachment] {
        Array(record.attachments.sorted { $0.placementSeed < $1.placementSeed }.prefix(4))
    }

    var body: some View {
        ZStack {
            pullObject
            insertFan
                .offset(y: 148)
            archiveChip
                .offset(y: 178)
            if let inspecting {
                AttachmentInspectionOverlay(attachment: inspecting) {
                    closeInspection()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 390)
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .task { await runIdleBreathe() }
        .sensoryFeedback(.impact(weight: .medium), trigger: thresholdPulse)
    }

    private var pullObject: some View {
        ZStack {
            emergedContents
                .mask(emergenceMask)
                .zIndex(1)

            jacket
                .offset(x: -46)
                .zIndex(2)
                .onTapGesture {
                    if revealed { collapse() }
                }
        }
        .frame(width: 390, height: 260)
    }

    private var emergedContents: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Palette.offWhite)
                .frame(width: 218, height: 218)
                .overlay(
                    Circle()
                        .strokeBorder(Palette.inkOnStage.opacity(0.12), lineWidth: 1)
                        .frame(width: 74, height: 74)
                )
                .offset(x: -10)
                .shadow(color: Palette.warmShadow.opacity(0.35), radius: 8, y: 5)
                .zIndex(0)

            RecordDiscView(record: record)
                .frame(width: 218, height: 218)
                .offset(x: recordX)
                .rotationEffect(.degrees(Double(1.8 * pullProgress)))
                .shadow(color: Palette.warmShadow, radius: 14, y: 10)
                .zIndex(1)
        }
    }

    private var jacket: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Palette.offWhite, Color(red: 0.88, green: 0.87, blue: 0.84)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 226, height: 226)
            .overlay(
                RecordCoverArtworkView(record: record)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .padding(7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 0.8)
            )
            .shadow(color: Palette.warmShadow, radius: 18, y: 12)
    }

    private var emergenceMask: some View {
        ZStack {
            Rectangle()
                .frame(width: 260, height: 252)
                .offset(x: 195)
        }
    }

    @ViewBuilder
    private var insertFan: some View {
        if revealed && attachments.isEmpty {
            Text("nothing else in the package")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.inkOnStage.opacity(0.42))
                .padding(.top, 4)
        } else {
            ZStack {
                ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                    fanObject(attachment, index: index)
                }
            }
            .frame(height: 150)
        }
    }

    @ViewBuilder
    private var archiveChip: some View {
        if revealed && !record.attachments.isEmpty {
            NavigationLink {
                PackageArchiveView(record: record)
            } label: {
                Label("View all · \(record.attachments.count)", systemImage: "shippingbox")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.glass)
            .tint(Palette.inkOnStage)
        }
    }

    private func fanObject(_ attachment: PackageAttachment, index: Int) -> some View {
        var rng = SeededRandom(seed: attachment.placementSeed)
        let jitter = rng.double(in: -3.5...3.5)
        let rotations = [-14.0, -5.0, 7.0, 16.0]
        let offsets: [CGPoint] = [
            CGPoint(x: -96, y: 6),
            CGPoint(x: -34, y: 24),
            CGPoint(x: 38, y: 18),
            CGPoint(x: 104, y: 4),
        ]
        let visible = fanCount > index

        return AttachmentObjectView(kind: attachment.kind, seed: attachment.placementSeed)
            .scaleEffect(0.45)
            .rotationEffect(.degrees(rotations[index] + jitter))
            .offset(x: visible ? offsets[index].x : 0, y: visible ? offsets[index].y : -26)
            .opacity(visible ? 1 : 0)
            .shadow(color: Palette.warmShadow.opacity(0.5), radius: 8, y: 5)
            .zIndex(Double(index))
            .animation(.spring(response: 0.48, dampingFraction: 0.72), value: fanCount)
            .onTapGesture {
                guard visible else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    inspecting = attachment
                }
            }
    }

    private var recordX: CGFloat {
        if revealed {
            return SleevePullMath.recordOffset(progress: 1)
        }
        return SleevePullMath.recordOffset(progress: pullProgress) + idlePeek
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let next = SleevePullMath.progress(for: value.translation.width)
                if SleevePullMath.crossedThreshold(previous: pullProgress, current: next) {
                    thresholdPulse += 1
                }
                idlePeek = 0
                revealed = false
                fanCount = 0
                pullProgress = next
            }
            .onEnded { _ in
                if SleevePullMath.resolvesRevealed(progress: pullProgress) {
                    reveal()
                } else {
                    collapse()
                }
            }
    }

    private func reveal() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            pullProgress = 1
            revealed = true
        }
        Task {
            for index in attachments.indices {
                try? await Task.sleep(for: .milliseconds(index == 0 ? 20 : 30))
                await MainActor.run {
                    fanCount = index + 1
                }
            }
        }
    }

    private func collapse() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            revealed = false
            pullProgress = 0
            fanCount = 0
        }
    }

    private func closeInspection() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            inspecting = nil
        }
    }

    private func runIdleBreathe() async {
        guard !reduceMotion else { return }
        try? await Task.sleep(for: .milliseconds(1200))
        guard !revealed && pullProgress == 0 else { return }
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.45)) { idlePeek = 4 }
        }
        try? await Task.sleep(for: .milliseconds(460))
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.45)) { idlePeek = 0 }
        }
    }
}
