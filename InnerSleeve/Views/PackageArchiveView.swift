import SwiftUI
import SwiftData

/// Package Archive: the physical contents of a record's package laid out
/// like objects on a charcoal work table — deliberately not a form list.
struct PackageArchiveView: View {
    var record: Record
    @State private var inspecting: PackageAttachment? = nil

    private var attachments: [PackageAttachment] {
        record.attachments.sorted { $0.placementSeed < $1.placementSeed }
    }

    var body: some View {
        ZStack {
            tableSurface

            if attachments.isEmpty {
                emptyTable
            } else {
                ScrollView(showsIndicators: false) {
                    tableLayout
                        .padding(.top, 28)
                        .padding(.bottom, 80)
                }
            }

            if let attachment = inspecting {
                AttachmentInspectionOverlay(attachment: attachment) {
                    closeInspection()
                }
            }
        }
        .navigationTitle(record.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .sensoryFeedback(.impact(weight: .light), trigger: inspecting != nil)
    }

    // MARK: Table

    private var tableSurface: some View {
        ZStack {
            Palette.charcoal.ignoresSafeArea()
            // Faint wood-table sheen so objects feel placed, not floating.
            LinearGradient(
                colors: [Color.white.opacity(0.05), .clear, Color.black.opacity(0.25)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var tableLayout: some View {
        let rows = (attachments.count + 1) / 2
        return VStack(spacing: 0) {
            Text("EVERYTHING IN THE PACKAGE")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .kerning(1.6)
                .foregroundStyle(Palette.offWhite.opacity(0.35))
                .padding(.bottom, 20)

            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { col in
                        let index = row * 2 + col
                        if index < attachments.count {
                            placedObject(attachments[index])
                                .frame(maxWidth: .infinity)
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(height: 208)
            }
        }
        .padding(.horizontal, 18)
    }

    private func placedObject(_ attachment: PackageAttachment) -> some View {
        var rng = SeededRandom(seed: attachment.placementSeed)
        let rotation = rng.double(in: -7...7)
        let dx = rng.double(in: -12...12)
        let dy = rng.double(in: -10...10)

        return VStack(spacing: 8) {
            AttachmentObjectView(kind: attachment.kind, seed: attachment.placementSeed)
                .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
            Text(attachment.kind.displayName.uppercased())
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .kerning(1.0)
                .foregroundStyle(Palette.offWhite.opacity(0.45))
        }
        .rotationEffect(.degrees(rotation))
        .offset(x: dx, y: dy)
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                inspecting = attachment
            }
        }
    }

    private func closeInspection() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            inspecting = nil
        }
    }

    private var emptyTable: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 30))
                .foregroundStyle(Palette.offWhite.opacity(0.25))
            Text("Nothing archived for this copy yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.offWhite.opacity(0.5))
        }
    }
}

/// Each attachment kind rendered as a physical artifact.
struct AttachmentObjectView: View {
    var kind: AttachmentKind
    var seed: Int

    var body: some View {
        switch kind {
        case .lyricInsert: lyricInsert
        case .poster: poster
        case .obiStrip: obiStrip
        case .receipt: receipt
        case .hypeSticker: hypeSticker
        case .booklet: booklet
        case .signedItem: signedItem
        case .innerSleeve: innerSleeve
        }
    }

    private var paper: LinearGradient {
        LinearGradient(
            colors: [Palette.offWhite, Color(red: 0.88, green: 0.86, blue: 0.81)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var lyricInsert: some View {
        Rectangle()
            .fill(paper)
            .frame(width: 106, height: 148)
            .overlay(
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(0..<11, id: \.self) { i in
                        Capsule()
                            .fill(Palette.inkOnStage.opacity(0.35))
                            .frame(width: i.isMultiple(of: 4) ? 40 : 78, height: 2.5)
                    }
                }
                .padding(14),
                alignment: .topLeading
            )
    }

    private var poster: some View {
        Rectangle()
            .fill(paper)
            .frame(width: 150, height: 108)
            .overlay(
                CoverArtView(seed: seed &+ 5, style: .beam, initials: "")
                    .opacity(0.8)
            )
            .overlay(
                // Fold creases.
                ZStack {
                    Rectangle().fill(Color.black.opacity(0.10)).frame(width: 1)
                    Rectangle().fill(Color.black.opacity(0.10)).frame(height: 1)
                    Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1).offset(x: 1)
                    Rectangle().fill(Color.white.opacity(0.18)).frame(height: 1).offset(y: 1)
                }
            )
            .clipped()
    }

    private var obiStrip: some View {
        Rectangle()
            .fill(Palette.orangeAccent)
            .frame(width: 40, height: 158)
            .overlay(
                VStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 16, height: 14)
                    }
                    Spacer()
                    Rectangle()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 24, height: 26)
                }
                .padding(.vertical, 10)
            )
    }

    private var receipt: some View {
        ReceiptShape()
            .fill(Color.white)
            .frame(width: 78, height: 150)
            .overlay(
                VStack(alignment: .leading, spacing: 4) {
                    Capsule().fill(Color.black.opacity(0.5)).frame(width: 36, height: 3)
                    Spacer().frame(height: 4)
                    ForEach(0..<8, id: \.self) { _ in
                        HStack {
                            Capsule().fill(Color.black.opacity(0.3)).frame(width: 26, height: 2)
                            Spacer()
                            Capsule().fill(Color.black.opacity(0.3)).frame(width: 12, height: 2)
                        }
                    }
                    Spacer().frame(height: 4)
                    Capsule().fill(Color.black.opacity(0.55)).frame(width: 44, height: 3)
                }
                .padding(12),
                alignment: .top
            )
    }

    private var hypeSticker: some View {
        Circle()
            .fill(Palette.warmYellow)
            .frame(width: 104, height: 104)
            .overlay(
                VStack(spacing: 3) {
                    Capsule().fill(Color.black.opacity(0.85)).frame(width: 56, height: 5)
                    Capsule().fill(Color.black.opacity(0.7)).frame(width: 40, height: 3.5)
                    Capsule().fill(Color.black.opacity(0.7)).frame(width: 48, height: 3.5)
                }
            )
            .overlay(
                Circle().strokeBorder(Color.black.opacity(0.15), lineWidth: 2)
            )
    }

    private var booklet: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Rectangle()
                    .fill(paper)
                    .frame(width: 118, height: 118)
                    .overlay(Rectangle().strokeBorder(Color.black.opacity(0.08), lineWidth: 0.8))
                    .offset(x: CGFloat(i) * 4, y: CGFloat(i) * -4)
            }
            CoverArtView(seed: seed &+ 9, style: .quadrants, initials: "")
                .frame(width: 118, height: 118)
                .opacity(0.85)
                .offset(x: 8, y: -8)
        }
    }

    private var signedItem: some View {
        Rectangle()
            .fill(paper)
            .frame(width: 132, height: 100)
            .overlay(
                SignatureShape()
                    .stroke(Color(red: 0.15, green: 0.18, blue: 0.4).opacity(0.85), lineWidth: 1.8)
                    .padding(18)
            )
    }

    private var innerSleeve: some View {
        Rectangle()
            .fill(paper)
            .frame(width: 134, height: 134)
            .overlay(
                // Center hole showing the table through it.
                Circle()
                    .fill(Palette.charcoal)
                    .frame(width: 46, height: 46)
            )
            .overlay(
                Circle()
                    .strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
                    .frame(width: 46, height: 46)
            )
    }

    private struct ReceiptShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 6))
            // Jagged torn bottom edge.
            let teeth = 7
            let toothWidth = rect.width / CGFloat(teeth)
            for i in 0..<teeth {
                let x = rect.maxX - CGFloat(i) * toothWidth
                path.addLine(to: CGPoint(x: x - toothWidth / 2, y: rect.maxY))
                path.addLine(to: CGPoint(x: x - toothWidth, y: rect.maxY - 6))
            }
            path.closeSubpath()
            return path
        }
    }

    private struct SignatureShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY + 10))
            path.addCurve(
                to: CGPoint(x: rect.midX - 10, y: rect.midY - 4),
                control1: CGPoint(x: rect.minX + 18, y: rect.minY),
                control2: CGPoint(x: rect.midX - 30, y: rect.maxY)
            )
            path.addCurve(
                to: CGPoint(x: rect.midX + 26, y: rect.midY + 6),
                control1: CGPoint(x: rect.midX + 4, y: rect.minY + 6),
                control2: CGPoint(x: rect.midX + 12, y: rect.maxY - 4)
            )
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY - 8),
                control1: CGPoint(x: rect.midX + 40, y: rect.midY + 14),
                control2: CGPoint(x: rect.maxX - 20, y: rect.minY + 8)
            )
            return path
        }
    }
}

#Preview("Dense package archive") {
    let container = PreviewContainers.denseArchive
    let record = try! container.mainContext.fetch(FetchDescriptor<Record>()).first!
    return NavigationStack {
        PackageArchiveView(record: record)
    }
    .modelContainer(container)
}

#Preview("Empty archive") {
    let container = PreviewContainers.full
    let record = try! container.mainContext.fetch(FetchDescriptor<Record>()).first {
        $0.attachments.isEmpty
    }!
    return NavigationStack {
        PackageArchiveView(record: record)
    }
    .modelContainer(container)
}
