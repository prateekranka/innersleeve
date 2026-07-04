import Foundation

/// Deterministic groove-riding motion for the tonearm during playback.
///
/// Values are intentionally tiny so the UI can layer them on top of the
/// cueing angle without changing playback logic or track selection math.
struct TonearmPlaybackMotion: Equatable {
    let verticalOffset: Double
    let headshellRotationDegrees: Double

    static let zero = TonearmPlaybackMotion(verticalOffset: 0, headshellRotationDegrees: 0)

    static let maximumVerticalOffset: Double = 0.36
    static let maximumHeadshellRotationDegrees: Double = 0.09
    static let fadeInDuration: TimeInterval = 1.4

    static func values(playbackTime: TimeInterval, isPlaying: Bool) -> TonearmPlaybackMotion {
        guard isPlaying, playbackTime > 0 else { return .zero }

        let fade = fadeProgress(at: playbackTime)
        let verticalWave = normalizedWave(
            playbackTime,
            primaryFrequency: 0.86,
            secondaryFrequency: 1.73,
            secondaryPhase: 1.2
        )
        let rotationWave = normalizedWave(
            playbackTime,
            primaryFrequency: 0.63,
            secondaryFrequency: 1.41,
            secondaryPhase: 2.1
        )

        return TonearmPlaybackMotion(
            verticalOffset: verticalWave * maximumVerticalOffset * fade,
            headshellRotationDegrees: rotationWave * maximumHeadshellRotationDegrees * fade
        )
    }

    static func verticalOffset(playbackTime: TimeInterval, isPlaying: Bool) -> Double {
        values(playbackTime: playbackTime, isPlaying: isPlaying).verticalOffset
    }

    static func headshellRotationDegrees(playbackTime: TimeInterval, isPlaying: Bool) -> Double {
        values(playbackTime: playbackTime, isPlaying: isPlaying).headshellRotationDegrees
    }

    private static func fadeProgress(at playbackTime: TimeInterval) -> Double {
        let progress = min(max(playbackTime / fadeInDuration, 0), 1)
        return progress * progress * (3 - 2 * progress)
    }

    private static func normalizedWave(
        _ playbackTime: TimeInterval,
        primaryFrequency: Double,
        secondaryFrequency: Double,
        secondaryPhase: Double
    ) -> Double {
        let primary = sin(playbackTime * 2 * .pi * primaryFrequency) * 0.74
        let secondary = sin(playbackTime * 2 * .pi * secondaryFrequency + secondaryPhase) * 0.26
        return primary + secondary
    }
}
