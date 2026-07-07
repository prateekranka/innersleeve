import Foundation
import CoreGraphics

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

    // MARK: - Deck geometry (direct manipulation)

    /// Tonearm pivot, relative to the deck center, in the deck's 344×236 layout.
    static let pivotOffset = CGVector(dx: 66, dy: -96)

    /// Stylus tip at angle 0 (outer groove), relative to the deck center.
    static let restTipOffset = CGVector(dx: -24, dy: 40)

    static func pivotPoint(deckCenter: CGPoint) -> CGPoint {
        CGPoint(x: deckCenter.x + pivotOffset.dx, y: deckCenter.y + pivotOffset.dy)
    }

    /// On-screen stylus tip for a given arm angle. The tip vector is the
    /// angle-0 tip rotated around the pivot (clockwise-positive, y-down).
    static func tipPoint(angle: Double, deckCenter: CGPoint) -> CGPoint {
        let pivot = pivotPoint(deckCenter: deckCenter)
        let vx = deckCenter.x + restTipOffset.dx - pivot.x
        let vy = deckCenter.y + restTipOffset.dy - pivot.y
        let radians = angle * .pi / 180
        return CGPoint(
            x: pivot.x + vx * cos(radians) - vy * sin(radians),
            y: pivot.y + vx * sin(radians) + vy * cos(radians)
        )
    }

    /// Polar angle (degrees) of a touch point as seen from the pivot.
    static func fingerAngle(at location: CGPoint, deckCenter: CGPoint) -> Double {
        let pivot = pivotPoint(deckCenter: deckCenter)
        return atan2(location.y - pivot.y, location.x - pivot.x) * 180 / .pi
    }

    /// Wrap an angle delta into (-180, 180] so drags never jump a full turn.
    static func normalizedDeltaDegrees(_ delta: Double) -> Double {
        var value = delta.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value <= -180 { value += 360 }
        return value
    }

    /// Direct-manipulation drag: the arm swings exactly as far around the
    /// pivot as the finger does, from wherever it was grabbed. Clamped to
    /// the physical range so the arm never leaves the deck.
    static func draggedAngle(
        startArmAngle: Double,
        startLocation: CGPoint,
        currentLocation: CGPoint,
        deckCenter: CGPoint
    ) -> Double {
        let delta = normalizedDeltaDegrees(
            fingerAngle(at: currentLocation, deckCenter: deckCenter)
                - fingerAngle(at: startLocation, deckCenter: deckCenter)
        )
        return clampedAngle(startArmAngle + delta)
    }
}
