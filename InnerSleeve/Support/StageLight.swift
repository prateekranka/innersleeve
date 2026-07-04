import CoreGraphics
import Foundation
import Observation

@Observable
final class StageLight {
    var position: CGPoint {
        didSet {
            let clamped = StageLightMath.clamped(position: position)
            if position != clamped {
                position = clamped
            }
        }
    }

    var intensity: Double {
        didSet {
            let clamped = StageLightMath.clampedIntensity(intensity)
            if intensity != clamped {
                intensity = clamped
            }
        }
    }

    init(
        position: CGPoint = StageLightMath.defaultPosition,
        intensity: Double = 1
    ) {
        self.position = StageLightMath.clamped(position: position)
        self.intensity = StageLightMath.clampedIntensity(intensity)
    }
}

enum StageLightMath {
    static let defaultPosition = CGPoint(x: -0.45, y: -0.6)

    private static let legacyGlossAngle = -18.0
    private static let defaultRawAngle = atan2(defaultPosition.x, -defaultPosition.y) * 180 / .pi

    static func angle(from position: CGPoint) -> Double {
        atan2(position.x, -position.y) * 180 / .pi + (legacyGlossAngle - defaultRawAngle)
    }

    static func elevation(from position: CGPoint) -> Double {
        let distance = hypot(position.x, position.y)
        return max(0, min(1, 1 - distance / sqrt(2)))
    }

    static func proximity(from position: CGPoint) -> Double {
        max(0, min(1, 1 - hypot(position.x, position.y) / sqrt(2)))
    }

    static func clamped(position: CGPoint) -> CGPoint {
        CGPoint(
            x: max(-1, min(1, position.x)),
            y: max(-1, min(1, position.y))
        )
    }

    static func clampedIntensity(_ intensity: Double) -> Double {
        max(0, min(1, intensity))
    }
}
