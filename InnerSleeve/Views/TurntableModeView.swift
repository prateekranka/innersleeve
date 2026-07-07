import SwiftUI
import SwiftData

/// The tonearm's operational state.
enum ArmState {
    /// Parked off the record at the arm-rest clip.
    case rest
    /// Being manually positioned by the user.
    case cue
    /// Settled on the record, playing.
    case play
}

/// Turntable Mode: a fixed deck with a vertical stream of records
/// snapping onto the platter. Browsing by playing, not by opening cards.
///
/// Integrates Apple Music playback via `AppleMusicDeckPlayer` so the
/// on-deck record plays automatically. The tonearm itself is the
/// primary control: drag it to cue a track or park it to stop.
struct TurntableModeView: View {
    @Query private var allRecords: [Record]
    var deckTarget: Record? = nil

    @State private var selection: Int = 0
    @State private var position: Double = 0
    @State private var dragAnchor: Double? = nil
    @State private var isDragging = false
    @State private var armLiftPulse = false

    @State private var deckPlayer = AppleMusicDeckPlayer()

    /// Tonearm angle in degrees: rest -16, outer groove 0, inner groove +14.
    @State private var armAngle: Double = TonearmMath.restAngle

    /// Current operational state of the tonearm.
    @State private var armState: ArmState = .rest

    /// Whether the tonearm headshell is lifted above the record.
    @State private var isArmLifted: Bool = true
    @State private var isDraggingTonearm = false

    /// Arm angle and finger position captured when a stylus drag begins,
    /// so the arm swings 1:1 with the finger from wherever it was grabbed.
    @State private var tonearmDragStart: (angle: Double, location: CGPoint)? = nil

    /// The platter motor. Spins from the moment a record plays until the
    /// deck's stop button is pressed — lifting the stylus alone never stops it.
    @State private var isPlatterSpinning = false

    /// The record currently shown in the detail sheet.
    @State private var detailRecord: Record? = nil

    @Environment(\.modelContext) private var modelContext

    private let recordSpacing: CGFloat = 170
    private let discDiameter: CGFloat = 172
    private static let deckSpaceName = "deckSpace"

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
                    let deckCenter = CGPoint(x: midX, y: midY)

                    ZStack {
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
                            onStop: { stopDeck() },
                            isPlaying: isPlatterSpinning || deckPlayer.isPlaying
                        )
                        .position(x: midX, y: midY)
                        .zIndex(5)
                        .allowsHitTesting(true)

                        TonearmView(angle: armAngle, isLifted: isTonearmLifted, isEngaged: isDraggingTonearm)
                            .grooveRiding(isGrooveRiding)
                            .position(x: midX, y: midY)
                            .zIndex(30)
                            .allowsHitTesting(false)

                        // Invisible grab zone riding on the stylus tip: pick the
                        // arm up here and swing it anywhere on (or off) the record.
                        Color.clear
                            .frame(width: 88, height: 88)
                            .contentShape(Circle())
                            .position(TonearmMath.tipPoint(angle: armAngle, deckCenter: deckCenter))
                            .zIndex(40)
                            .highPriorityGesture(tonearmDragGesture(deckCenter: deckCenter))
                            .accessibilityLabel("Tonearm stylus")
                            .accessibilityHint("Drag onto the record to play from that spot, or back to the arm rest to lift it off")
                    }
                    .coordinateSpace(name: Self.deckSpaceName)
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
            isSpinning: factor > 0.9 && !isDragging && isPlatterSpinning
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
        .offset(x: -52 * factor, y: 0)
    }

    private func onDeckFactor(_ offset: Double) -> Double {
        max(0, 1 - min(abs(offset), 1))
    }

    // MARK: Drag / snap

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard !isDraggingTonearm else { return }
                if dragAnchor == nil {
                    dragAnchor = position
                    isDragging = true
                }
                let anchor = dragAnchor ?? position
                let raw = anchor - Double(value.translation.height) / Double(recordSpacing)
                position = CarouselGeometry.rubberBand(raw, count: records.count)
            }
            .onEnded { value in
                guard !isDraggingTonearm else {
                    dragAnchor = nil
                    isDragging = false
                    return
                }
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
            Task {
                await play(records[clamped], startingAt: 0, source: .recordChange)
            }
        }
    }

    private func pulseTonearm() {
        armLiftPulse = true
        armState = .rest
        withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) {
            armAngle = TonearmMath.restAngle
        }
        Task {
            try? await Task.sleep(for: .milliseconds(360))
            await MainActor.run {
                armLiftPulse = false
            }
        }
    }

    // MARK: Deck display

    private var displayText: String {
        if deckPlayer.isLoading {
            return deckPlayer.statusText
        }
        return AppleMusicDeckPlayer.deckTickerText(
            albumTitle: currentRecord?.title,
            trackTitle: deckPlayer.currentTrackTitle ?? currentRecord?.sequencedTracks.first?.title
        )
    }

    // MARK: Chrome

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
                TonearmView(angle: TonearmMath.restAngle, isLifted: true)
            }
            .scaleEffect(0.9)
            Text("Nothing on the deck")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.inkOnStage.opacity(0.7))
        }
    }

    // MARK: Tonearm

    /// Direct manipulation of the stylus: the arm swings around its pivot
    /// exactly as far as the finger does, from wherever it was grabbed.
    private func tonearmDragGesture(deckCenter: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.deckSpaceName))
            .onChanged { value in
                if tonearmDragStart == nil {
                    tonearmDragStart = (angle: armAngle, location: value.startLocation)
                }
                isDraggingTonearm = true
                armState = .cue
                isArmLifted = true
                guard let start = tonearmDragStart else { return }
                armAngle = TonearmMath.draggedAngle(
                    startArmAngle: start.angle,
                    startLocation: start.location,
                    currentLocation: value.location,
                    deckCenter: deckCenter
                )
            }
            .onEnded { _ in
                isDraggingTonearm = false
                tonearmDragStart = nil
                let finalAngle = TonearmMath.clampedAngle(armAngle)
                armAngle = finalAngle

                if let progress = TonearmMath.grooveProgress(at: finalAngle), let record = currentRecord {
                    let trackIndex = AppleMusicDeckPlayer.stylusCueTrackIndex(
                        progress: progress,
                        trackDurations: record.sequencedTracks.map(\.duration)
                    )
                    Task {
                        await play(record, startingAt: trackIndex, source: .stylusDrop, cueProgress: progress)
                    }
                } else {
                    // Off the grooved donut: either back on the arm rest or
                    // over the center label sticker, where a needle can't
                    // play. The music stops but the platter keeps spinning
                    // until the deck's stop button is pressed.
                    parkStylus()
                }
            }
    }

    /// Returns the arm to its rest clip and stops the audio. The platter
    /// motor is left alone — only `stopDeck()` turns it off.
    @MainActor
    private func parkStylus() {
        deckPlayer.stop()
        armState = .rest
        withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) {
            armAngle = TonearmMath.restAngle
        }
        isArmLifted = false
    }

    /// The deck's stop button: parks the arm and stops the platter.
    @MainActor
    private func stopDeck() {
        parkStylus()
        isPlatterSpinning = false
    }

    private var isTonearmLifted: Bool {
        if armLiftPulse { return true }
        if armState == .cue { return true }
        if deckPlayer.isLoading { return true }
        if deckPlayer.isPlaying { return isArmLifted }
        return false
    }

    private var isGrooveRiding: Bool {
        deckPlayer.isPlaying && armState == .play && !isTonearmLifted
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
        let seekSeconds = cueProgress.map { progress in
            AppleMusicDeckPlayer.stylusCueSeekSeconds(
                progress: progress,
                trackDurations: tracks.map(\.duration)
            )
        } ?? 0
        isArmLifted = true

        if let albumID = record.appleMusicAlbumID {
            await deckPlayer.play(
                albumID: albumID,
                startingAt: clampedIndex,
                seekToSeconds: seekSeconds,
                albumTitle: record.title,
                trackTitle: tracks[safe: clampedIndex]?.title
            )
        } else {
            await deckPlayer.loadAndPlay(
                record: record,
                startingAt: clampedIndex,
                seekToSeconds: seekSeconds,
                modelContext: modelContext
            )
        }

        if deckPlayer.isPlaying {
            isArmLifted = false
            armState = .play
            isPlatterSpinning = true
            if source != .stylusDrop {
                // Auto-plays settle the arm on the track's groove within the
                // playable donut. A stylus drop stays where the user placed it.
                let trackProgress = tracks.count > 1
                    ? Double(clampedIndex) / Double(tracks.count - 1)
                    : 0
                let targetAngle = TonearmMath.angle(forGrooveProgress: trackProgress)
                withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
                    armAngle = TonearmMath.clampedAngle(targetAngle)
                }
            }
            if let track = tracks[safe: clampedIndex] {
                record.logTrackPlay(track: track, source: source, cueProgress: cueProgress)
                try? modelContext.save()
            }
        } else {
            isArmLifted = false
            armState = .rest
            withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) {
                armAngle = TonearmMath.restAngle
            }
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
                        if deckPlayer.isLoading {
                            ProgressView()
                                .scaleEffect(0.4)
                                .frame(width: 6, height: 6)
                        } else {
                            Circle()
                                .fill(deckPlayer.isPlaying ? Palette.orangeAccent : Palette.inkOnStage.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
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
