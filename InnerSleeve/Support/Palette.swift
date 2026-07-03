import SwiftUI

/// The Inner Sleeve palette, straight from the reference teardown.
enum Palette {
    static let stageGrey = Color(red: 0.910, green: 0.910, blue: 0.898)      // #E8E8E5
    static let stageGreyDeep = Color(red: 0.855, green: 0.855, blue: 0.843)
    static let charcoal = Color(red: 0.063, green: 0.090, blue: 0.110)       // #10171C
    static let vinylBlack = Color(red: 0.020, green: 0.020, blue: 0.020)     // #050505
    static let softBlack = Color(red: 0.141, green: 0.137, blue: 0.129)      // #242321
    static let offWhite = Color(red: 0.953, green: 0.949, blue: 0.929)       // #F3F2ED
    static let warmYellow = Color(red: 0.949, green: 0.698, blue: 0.102)     // #F2B21A
    static let amberDisplay = Color(red: 0.961, green: 0.698, blue: 0.227)   // #F5B23A
    static let orangeAccent = Color(red: 0.949, green: 0.353, blue: 0.114)   // #F25A1D
    static let metalGrey = Color(red: 0.784, green: 0.788, blue: 0.773)      // #C8C9C5
    static let warmShadow = Color.black.opacity(0.18)
    static let inkOnStage = Color(red: 0.16, green: 0.16, blue: 0.15)

    /// Label-art ink colors that cover art generation draws from.
    static let labelInks: [Color] = [
        warmYellow,
        orangeAccent,
        Color(red: 0.16, green: 0.32, blue: 0.36),   // slate teal
        Color(red: 0.73, green: 0.26, blue: 0.16),   // brick
        Color(red: 0.22, green: 0.24, blue: 0.45),   // night blue
        Color(red: 0.36, green: 0.42, blue: 0.24),   // olive
        Color(red: 0.87, green: 0.82, blue: 0.72),   // parchment
        Color(red: 0.55, green: 0.36, blue: 0.55),   // dusk plum
    ]

    /// Label paper background tones.
    static let labelPapers: [Color] = [
        offWhite,
        Color(red: 0.93, green: 0.88, blue: 0.78),
        Color(red: 0.14, green: 0.15, blue: 0.16),
        Color(red: 0.85, green: 0.80, blue: 0.70),
        Color(red: 0.20, green: 0.22, blue: 0.25),
    ]
}

/// Deterministic random generator so cover art is stable per record.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed)) &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func double(in range: ClosedRange<Double>) -> Double {
        Double.random(in: range, using: &self)
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        Int.random(in: range, using: &self)
    }

    mutating func pick<T>(_ array: [T]) -> T {
        array[int(in: 0...(array.count - 1))]
    }
}
