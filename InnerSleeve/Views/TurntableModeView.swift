import SwiftUI
import SwiftData

/// Turntable Mode: a fixed deck with a vertical stream of records
/// snapping onto the platter. Browsing by playing, not by opening cards.
///
/// Integrates Apple Music playback via `AppleMusicDeckPlayer` so the
/// on-deck record plays automatically. A stylus-cue gesture lets the
/// user drop the needle at a different track.
struct TurntableModeView: View {
    @Query private var allRecords: [Record]
    var deckTarget: Record? = nil

    @State private var selection: Int = 0
    @State private var position: Double = 0
    @State private var dragAnchor: Double? = nil
    @State private var isDragging = false
    @State private var armLiftPulse = false
    @State private var isStylusLifted = true
    @State private var detailRecord: Record? = nil

    @State private var deckPlayer = AppleMusicDeckPlayer()
    @Environment(\.modelContext) private var modelContext

    /// 0 at the outer groove and 1 near the spindle while cueing; nil otherwise.
    @State private var stylusCueProgress: Double? = nil

    private let recordSpacing: CGFloat = 190
    private let discDiameter: CGFloat = 204

    /// Stable order — the queue must not reshuffle while records move through it.
    private var records: [Record] {
        Record.shelfOrder(allRecords)
    }

    private var currentRecord: Record? {
        guard records.indices.contains(selection) else { return nil }
        return records[selection]
    }

    private var snapSpring: Animation {
        .spring(response: 0.5, dampingFraction: 0.72)
    }

    var body: some View {
        ZStack {
            Palette.stageGrey.ignoresSafeArea()

            if records.isEmpty {
                emptyDeck
            } else {
                GeometryReader { proxy in
                    let midX = proxy.size.width / 2
                    let midY = proxy.size.height / 2 - 30

                    ZStack {
                        // Queue records (off the deck).
                        ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                            let offset = Double(index) - position
                            if abs(offset) <= 2.5 {
                                queueDisc(record: record, offset: offset)
                                    .position(x: midX, y: midY + CGFloat(offset) * recordSpacing)
                                    .zIndex(onDeckFactor(offset) > 0.5 ? 10 : 1)
                            }
                        }

                        TurntableDeckView(
                            displayText: displayText,
                            stylusCueProgress: stylusCueProgress
                        )
                        .position(x: midX, y: midY)
                        .zIndex(5)
                        .allowsHitTesting(true)

                        TonearmView(isLifted: isTonearmLifted)
                            .position(x: midX, y: midY)
                            .zIndex(30)

                        tonearmStopControl
                            .position(x: midX, y: midY)
                            .zIndex(35)

                        // Stylus cue drag area sits on top of the on-deck record.
                        if onDeckFactor(0) > 0.9, let _ = currentRecord {
                            stylusCueDragZone
                                .position(x: midX, y: midY)
                                .zIndex(40)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(dragGesture)
                }

                logPlayControl
                appleMusicStatusControl
            }
        }
        .onAppear { position = Double(selection) }
        .onChange(of: deckTarget?.persistentModelID) { _, _ in
            snapToDeckTarget()
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: selection)
        .sheet(item: $detailRecord) { record in
            RecordDetailView(record: record)
        }
    }

    private func snapToDeckTarget() {
        guard let targetID = deckTarget?.persistentModelID,
              let index = records.firstIndex(where: { $0.persistentModelID == targetID }) else {
            return
        }
        snap(to: index)
    }

    // MARK: Record rendering

    @ViewBuilder
    private func queueDisc(record: Record, offset: Double) -> some View {
        let factor = onDeckFactor(offset)
        let scale = 0.68 + 0.32 * factor
        let opacity = abs(offset) > 2 ? 0.25 : 1.0

        SpinningDisc(
            record: record,
            isSpinning: factor > 0.9 && !isDragging
        )
        .frame(width: discDiameter, height: discDiameter)
        .scaleEffect(scale)
        .opacity(opacity)
        .shadow(
            color: Palette.warmShadow.opacity(factor > 0.5 ? 1.0 : 0.4),
            radius: factor > 0.5 ? 22 : 10,
            y: factor > 0.5 ? 14 : 6
        )
        .onTapGesture {
            if factor > 0.5 {
                detailRecord = record
            } else {
                let index = Int((Double(selection) + offset).rounded())
                snap(to: index)
            }
        }
        // The platter record eases toward the platter side as it lands.
        .offset(x: -52 * factor, y: 0)
    }

    /// 1.0 when a record is centered on the platter, easing to 0 as it leaves.
    private func onDeckFactor(_ offset: Double) -> Double {
        max(0, 1 - min(abs(offset), 1))
    }

    // MARK: Drag / snap

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if dragAnchor == nil {
                    dragAnchor = position
                    isDragging = true
                }
                let anchor = dragAnchor ?? position
                let raw = anchor - Double(value.translation.height) / Double(recordSpacing)
                position = CarouselGeometry.rubberBand(raw, count: records.count)
            }
            .onEnded { value in
                dragAnchor = nil
                isDragging = false
                let flick = Double(value.predictedEndTranslation.height - value.translation.height)
                let velocity = -flick / Double(recordSpacing)
                let target = CarouselGeometry.snapTarget(
                    position: position,
                    velocity: velocity,
                    count: records.count
                )
                snap(to: target)
            }
    }

    private func snap(to index: Int) {
        let clamped = min(max(index, 0), records.count - 1)
        withAnimation(snapSpring) { position = Double(clamped) }
        if selection != clamped {
            pulseTonearm()
            selection = clamped
            // Load album on record change.
            Task {
                await play(records[clamped], startingAt: 0, source: .recordChange)
            }
        }
    }

    private func pulseTonearm() {
        armLiftPulse = true
        Task {
            try? await Task.sleep(for: .milliseconds(360))
            await MainActor.run {
                armLiftPulse = false
            }
        }
    }

    // MARK: Deck display

    private var displayText: String {
        AppleMusicDeckPlayer.deckTickerText(
            albumTitle: currentRecord?.title,
            trackTitle: deckPlayer.currentTrackTitle ?? currentRecord?.sequencedTracks.first?.title
        )
    }

    // MARK: Chrome

    /// Explicit "needle drop": logs a listen for the record on the platter.
    private var logPlayControl: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    currentRecord?.logPlay()
                } label: {
                    Label("Log play", systemImage: "waveform")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.glassProminent)
                .tint(Palette.orangeAccent)
                .padding(.trailing, 22)
                .padding(.bottom, 110)
            }
        }
        .sensoryFeedback(.success, trigger: currentRecord?.playCount ?? 0)
    }

    private var emptyDeck: some View {
        VStack(spacing: 18) {
            ZStack {
                TurntableDeckView(displayText: "Queue empty")
                TonearmView(isLifted: true)
            }
            .scaleEffect(0.9)
            Text("Nothing on the deck")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.inkOnStage.opacity(0.7))
        }
    }

    // MARK: Stylus cue

    /// Transparent drag zone overlaying the on-deck record.
    /// Measures the radial distance from the record center and maps it
    /// to 0 at the outer groove and 1 near the spindle.
    private var stylusCueDragZone: some View {
        Color.clear
            .frame(width: discDiameter, height: discDiameter)
            .contentShape(Circle())
            .onTapGesture {
                if let record = currentRecord {
                    detailRecord = record
                }
            }
            .gesture(stylusCueGesture)
    }

    private var stylusCueGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let centerX = discDiameter / 2
                let centerY = discDiameter / 2
                let dx = value.location.x - centerX
                let dy = value.location.y - centerY
                let distance = sqrt(dx * dx + dy * dy)
                let maxRadius = discDiameter / 2
                let progress = 1 - min(max(distance / maxRadius, 0), 1)
                stylusCueProgress = progress
            }
            .onEnded { _ in
                guard let progress = stylusCueProgress,
                      let record = currentRecord,
                      !record.sequencedTracks.isEmpty else {
                    stylusCueProgress = nil
                    return
                }
                let trackIndex = AppleMusicDeckPlayer.stylusCueTrackIndex(
                    progress: progress,
                    trackDurations: record.sequencedTracks.map(\.duration)
                )
                stylusCueProgress = nil

                Task {
                    await play(record, startingAt: trackIndex, source: .stylusDrop, cueProgress: progress)
                }
            }
    }

    private var tonearmStopControl: some View {
        Button {
            liftStylus()
        } label: {
            Color.clear
                .frame(width: 156, height: 214)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: 40, y: -12)
        .accessibilityLabel("Lift stylus")
        .accessibilityHint("Stops Apple Music playback")
    }

    private var isTonearmLifted: Bool {
        isDragging || armLiftPulse || stylusCueProgress != nil || isStylusLifted || !deckPlayer.isPlaying
    }

    @MainActor
    private func liftStylus() {
        deckPlayer.stop()
        isStylusLifted = true
    }

    @MainActor
    private func play(
        _ record: Record,
        startingAt trackIndex: Int,
        source: PlayLogSource,
        cueProgress: Double? = nil
    ) async {
        let tracks = record.sequencedTracks
        let clampedIndex = AppleMusicDeckPlayer.clampedTrackIndex(trackIndex, trackCount: tracks.count)
        isStylusLifted = false
        if let albumID = record.appleMusicAlbumID {
            await deckPlayer.play(
                albumID: albumID,
                startingAt: clampedIndex,
                albumTitle: record.title,
                trackTitle: tracks[safe: clampedIndex]?.title
            )
        } else {
            await deckPlayer.loadAndPlay(record: record, startingAt: clampedIndex, modelContext: modelContext)
        }

        if deckPlayer.isPlaying, let track = tracks[safe: clampedIndex] {
            record.logTrackPlay(track: track, source: source, cueProgress: cueProgress)
            try? modelContext.save()
        } else {
            isStylusLifted = true
        }
    }

    // MARK: Apple Music status control

    private var appleMusicStatusControl: some View {
        VStack {
            Spacer()
            HStack {
                Button {
                    if let record = currentRecord {
                        Task { await play(record, startingAt: 0, source: .recordChange) }
                    } else if deckPlayer.authorizationUndetermined {
                        Task { await deckPlayer.requestAuthorization() }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(deckPlayer.isPlaying ? Palette.orangeAccent : Palette.inkOnStage.opacity(0.3))
                            .frame(width: 6, height: 6)
                        Text(deckPlayer.statusText)
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(.glass)
                .tint(deckPlayer.isAuthorized ? Palette.amberDisplay : Palette.inkOnStage)
                .disabled(!deckPlayer.isAuthorized && !deckPlayer.authorizationUndetermined)
                .padding(.leading, 22)
                .padding(.bottom, 110)
                Spacer()
            }
        }
    }
}

/// A record that rotates slowly while it sits on the platter.
private struct SpinningDisc: View {
    var record: Record
    var isSpinning: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isSpinning)) { context in
            let angle = isSpinning
                ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 12) / 12 * 360
                : 0
            RecordDiscView(record: record)
                .rotationEffect(.degrees(angle))
        }
    }
}

#Preview("Turntable · full collection") {
    TurntableModeView()
        .modelContainer(PreviewContainers.full)
}

#Preview("Turntable · empty") {
    TurntableModeView()
        .modelContainer(PreviewContainers.empty)
}
