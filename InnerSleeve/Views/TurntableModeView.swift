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

    /// The physical face currently exposed on the platter.
    @State private var activeSide: RecordSide = .a

    /// Direct-manipulation state for lifting and turning the on-deck record.
    @State private var recordFlipRotation: Double = 0
    @State private var recordFlipOffset: CGFloat = 0
    @State private var recordFlipLift: CGFloat = 0
    @State private var isFlippingRecord = false
    @State private var recordFlipFeedback = 0
    @State private var recordFlipTask: Task<Void, Never>?
    @State private var playbackTask: Task<Void, Never>?
    @State private var armLiftTask: Task<Void, Never>?

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
                            activeSide: activeSide,
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
                    .coordinateSpace(.named(Self.deckSpaceName))
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
        .onDisappear {
            cancelTransientDeckWork()
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: selection)
        .sensoryFeedback(.impact(weight: .heavy), trigger: recordFlipFeedback)
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
            side: factor > 0.9 ? activeSide : .a,
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
        .rotation3DEffect(
            .degrees(factor > 0.9 ? recordFlipRotation : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.55
        )
        .onTapGesture {
            if factor > 0.5 {
                detailRecord = record
            } else {
                let index = Int((Double(selection) + offset).rounded())
                snap(to: index)
            }
        }
        .offset(
            x: -52 * factor + (factor > 0.9 ? recordFlipOffset : 0),
            y: factor > 0.9 ? recordFlipLift : 0
        )
        .highPriorityGesture(recordFlipGesture(for: record))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(record.title), \((factor > 0.9 ? activeSide : RecordSide.a).displayName)")
        .accessibilityHint(factor > 0.9 ? "Hold and slide sideways to flip the record" : "Double tap to put this record on the deck")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            if factor > 0.5 {
                detailRecord = record
            } else {
                let index = Int((Double(selection) + offset).rounded())
                snap(to: index)
            }
        }
        .accessibilityAction(named: "Flip record") {
            guard factor > 0.9, !isFlippingRecord else { return }
            beginRecordFlip()
            completeRecordFlip(direction: 1)
        }
    }

    private func onDeckFactor(_ offset: Double) -> Double {
        max(0, 1 - min(abs(offset), 1))
    }

    // MARK: Drag / snap

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard !isDraggingTonearm, !isFlippingRecord else { return }
                if dragAnchor == nil {
                    dragAnchor = position
                    isDragging = true
                }
                let anchor = dragAnchor ?? position
                let raw = anchor - Double(value.translation.height) / Double(recordSpacing)
                position = CarouselGeometry.rubberBand(raw, count: records.count)
            }
            .onEnded { value in
                guard !isDraggingTonearm, !isFlippingRecord else {
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
            stopDeck()
            resetRecordFace()
            pulseTonearm()
            selection = clamped
        }
    }

    // MARK: Record flip

    /// A short hold distinguishes picking up the record from scrolling the
    /// vertical queue. Once held, horizontal movement tips the disc in 3D.
    private func recordFlipGesture(for record: Record) -> some Gesture {
        LongPressGesture(minimumDuration: 0.22, maximumDistance: 14)
            .sequenced(
                before: DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .named(Self.deckSpaceName)
                )
            )
            .onChanged { value in
                guard record.persistentModelID == currentRecord?.persistentModelID else { return }

                switch value {
                case .first(true):
                    beginRecordFlip()
                case let .second(true, drag?):
                    beginRecordFlip()
                    updateRecordFlip(translation: drag.translation)
                default:
                    break
                }
            }
            .onEnded { value in
                guard record.persistentModelID == currentRecord?.persistentModelID,
                      isFlippingRecord else { return }

                if case let .second(true, drag?) = value,
                   abs(drag.translation.width) >= 62,
                   abs(drag.translation.width) > abs(drag.translation.height) {
                    completeRecordFlip(direction: drag.translation.width >= 0 ? 1 : -1)
                } else {
                    cancelRecordFlip()
                }
            }
    }

    @MainActor
    private func beginRecordFlip() {
        guard !isFlippingRecord else { return }
        recordFlipTask?.cancel()
        recordFlipTask = nil
        isFlippingRecord = true

        // A record cannot remain under a live stylus while it is lifted.
        stopDeck()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
            recordFlipLift = -8
        }
    }

    @MainActor
    private func updateRecordFlip(translation: CGSize) {
        let horizontal = min(max(translation.width, -92), 92)
        let progress = min(abs(horizontal) / 92, 1)
        recordFlipOffset = horizontal * 0.18
        recordFlipRotation = (horizontal >= 0 ? 1 : -1) * progress * 82
        recordFlipLift = -8 - progress * 10
    }

    @MainActor
    private func cancelRecordFlip() {
        recordFlipTask?.cancel()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
            recordFlipRotation = 0
            recordFlipOffset = 0
            recordFlipLift = 0
        }

        recordFlipTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(340))
            } catch {
                return
            }
            isFlippingRecord = false
        }
    }

    @MainActor
    private func completeRecordFlip(direction: Double) {
        recordFlipTask?.cancel()
        recordFlipTask = Task { @MainActor in
            withAnimation(.easeIn(duration: 0.15)) {
                recordFlipRotation = direction * 90
                recordFlipOffset = direction * 18
                recordFlipLift = -18
            }

            do {
                try await Task.sleep(for: .milliseconds(150))
            } catch {
                return
            }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                activeSide = activeSide == .a ? .b : .a
                recordFlipRotation = -direction * 90
                recordFlipOffset = -direction * 18
            }
            recordFlipFeedback += 1

            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                recordFlipRotation = 0
                recordFlipOffset = 0
                recordFlipLift = 0
            }

            do {
                try await Task.sleep(for: .milliseconds(380))
            } catch {
                return
            }
            isFlippingRecord = false
        }
    }

    private func resetRecordFace() {
        recordFlipTask?.cancel()
        recordFlipTask = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activeSide = .a
            recordFlipRotation = 0
            recordFlipOffset = 0
            recordFlipLift = 0
            isFlippingRecord = false
        }
    }

    @MainActor
    private func cancelTransientDeckWork() {
        recordFlipTask?.cancel()
        recordFlipTask = nil
        playbackTask?.cancel()
        playbackTask = nil
        armLiftTask?.cancel()
        armLiftTask = nil
        deckPlayer.stop()

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            recordFlipRotation = 0
            recordFlipOffset = 0
            recordFlipLift = 0
            isFlippingRecord = false
            tonearmDragStart = nil
            isDraggingTonearm = false
            dragAnchor = nil
            isDragging = false
            armLiftPulse = false
            armState = .rest
            armAngle = TonearmMath.restAngle
            isArmLifted = false
            isPlatterSpinning = false
        }
    }

    private func pulseTonearm() {
        armLiftTask?.cancel()
        armLiftPulse = true
        armState = .rest
        withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) {
            armAngle = TonearmMath.restAngle
        }
        armLiftTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(360))
            } catch {
                return
            }
            armLiftPulse = false
        }
    }

    // MARK: Deck display

    private var displayText: String {
        if deckPlayer.isLoading {
            return deckPlayer.statusText
        }
        return AppleMusicDeckPlayer.deckTickerText(
            albumTitle: currentRecord?.title,
            trackTitle: deckPlayer.currentTrackTitle ?? currentRecord?.tracks(on: activeSide).first?.title,
            side: activeSide
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
                    playbackTask?.cancel()
                    deckPlayer.stop()
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
                    let sideTracks = record.tracks(on: activeSide)
                    let trackIndex = AppleMusicDeckPlayer.stylusCueTrackIndex(
                        progress: progress,
                        trackDurations: sideTracks.map(\.duration)
                    )
                    startPlayback(
                        record,
                        startingAt: trackIndex,
                        cueProgress: progress
                    )
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
        playbackTask?.cancel()
        playbackTask = nil
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
        deckPlayer.isPlaying
            && deckPlayer.currentSide == activeSide
            && armState == .play
            && !isTonearmLifted
    }

    @MainActor
    private func startPlayback(
        _ record: Record,
        startingAt trackIndex: Int,
        cueProgress: Double? = nil
    ) {
        playbackTask?.cancel()
        playbackTask = Task { @MainActor in
            await play(
                record,
                startingAt: trackIndex,
                cueProgress: cueProgress
            )
        }
    }

    @MainActor
    private func play(
        _ record: Record,
        startingAt trackIndex: Int,
        cueProgress: Double? = nil
    ) async {
        let side = activeSide
        let tracks = record.tracks(on: side)
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
                side: side,
                startingAt: clampedIndex,
                seekToSeconds: seekSeconds,
                albumTitle: record.title,
                trackTitle: tracks[safe: clampedIndex]?.title,
                catalogTrackRange: record.catalogTrackRange(for: side),
                sideTrackTitles: tracks.map(\.title)
            )
        } else {
            await deckPlayer.loadAndPlay(
                record: record,
                side: side,
                startingAt: clampedIndex,
                seekToSeconds: seekSeconds,
                modelContext: modelContext
            )
        }

        guard !Task.isCancelled else { return }

        if deckPlayer.isPlaying, deckPlayer.currentSide == side {
            isArmLifted = false
            armState = .play
            isPlatterSpinning = true
            if let track = tracks[safe: clampedIndex] {
                record.logTrackPlay(track: track, source: .stylusDrop, cueProgress: cueProgress)
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
                Group {
                    if deckPlayer.authorizationUndetermined {
                        Button {
                            Task { await deckPlayer.requestAuthorization() }
                        } label: {
                            appleMusicStatusLabel
                        }
                        .buttonStyle(.glass)
                        .tint(Palette.inkOnStage)
                    } else {
                        appleMusicStatusLabel
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.thinMaterial, in: Capsule())
                            .foregroundStyle(
                                deckPlayer.isAuthorized
                                    ? Palette.amberDisplay
                                    : Palette.inkOnStage.opacity(0.65)
                            )
                            .accessibilityElement(children: .combine)
                    }
                }
                .padding(.leading, 22)
                .padding(.bottom, 110)
                Spacer()
            }
        }
    }

    private var appleMusicStatusLabel: some View {
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
}

/// A record that rotates slowly while it sits on the platter.
private struct SpinningDisc: View {
    var record: Record
    var side: RecordSide
    var isSpinning: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isSpinning)) { context in
            let angle = isSpinning
                ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 12) / 12 * 360
                : 0
            ZStack {
                RecordDiscView(record: record)
                RecordSideFaceMark(side: side)
            }
            .rotationEffect(.degrees(angle))
        }
    }
}

private struct RecordSideFaceMark: View {
    let side: RecordSide

    var body: some View {
        Text(side.rawValue)
            .font(.system(size: 8, weight: .black, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.88))
            .frame(width: 15, height: 15)
            .background(Color.black.opacity(0.62), in: Circle())
            .offset(y: 19)
            .accessibilityHidden(true)
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
