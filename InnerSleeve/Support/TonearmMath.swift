import Foundation

/// Pure math for tonearm angle ↔ progress ↔ track mapping.
/// No UI state; safe for tests and previews.
///
/// The tonearm sweeps across the record from rest (-16°) through
/// the outer groove (0°) to the inner groove (+14° near the spindle).
enum TonearmMath {

    // MARK: - Angle constants

    /// Rest position: arm parked off the record at the arm-rest clip.
    static let restAngle: Double = -16

    /// Outer groove (first track on the record).
    static let outerGrooveAngle: Double = 0

    /// Inner groove (last track, near the spindle).
    static let innerGrooveAngle: Double = 14

    /// Valid angle range: rest through inner groove.
    static let angleRange: ClosedRange<Double> = restAngle ... innerGrooveAngle

    // MARK: - Clamping

    /// Clamp arm angle to the valid range [-16, 14].
    static func clampedAngle(_ angle: Double) -> Double {
        min(max(angle, restAngle), innerGrooveAngle)
    }

    // MARK: - Record detection

    /// Whether the given angle positions the stylus over the record.
    static func isOnRecord(_ angle: Double) -> Bool {
        angle >= outerGrooveAngle
    }

    // MARK: - Progress mapping

    /// Map arm angle to cue progress (nil when off-record).
    ///
    /// Returns 0 at the outer groove and 1 at the inner groove.
    /// Returns nil when the arm is parked in the rest region.
    static func cueProgress(from angle: Double) -> Double? {
        guard isOnRecord(angle) else { return nil }
        let clamped = clampedAngle(angle)
        return (clamped - outerGrooveAngle) / (innerGrooveAngle - outerGrooveAngle)
    }

    // MARK: - Track mapping

    /// Map arm angle to a 0-based track index using even track spacing.
    ///
    /// - Parameters:
    ///   - angle: Current tonearm angle in degrees.
    ///   - trackCount: Number of tracks on the record side.
    /// - Returns: 0-based index clamped to valid range.
    static func trackIndex(from angle: Double, trackCount: Int) -> Int {
        guard trackCount > 0 else { return 0 }
        guard let progress = cueProgress(from: angle) else { return 0 }
        let index = Int((progress * Double(trackCount - 1)).rounded())
        return min(max(index, 0), trackCount - 1)
    }

    /// Map the currently playing track to a visible groove position.
    ///
    /// Records that do not yet have local track metadata still place the
    /// stylus at the outer groove so Apple Music-backed playback has a
    /// physical arm state.
    static func playbackAngle(trackIndex: Int, trackCount: Int) -> Double {
        guard trackCount > 1 else { return outerGrooveAngle }
        let clampedIndex = min(max(trackIndex, 0), trackCount - 1)
        return outerGrooveAngle
            + (Double(clampedIndex) / Double(trackCount - 1))
            * (innerGrooveAngle - outerGrooveAngle)
    }
}
