import Foundation

/// The sounds, made up at start from damped resonances and noise: struck bodies for the dice and the checkers, bells
/// for a turn that passes and for a win.
enum SoundSynth {
    static let rate = 44_100.0

    /// Every effect's samples, in the order of `SoundEffect`. The rattle and the checkers set out share one
    /// generator, which gives each knock its own pitch, moment and loudness.
    static func all() -> [[Float]] {
        var random = MinimalRandom(seed: 23)
        return SoundEffect.allCases.map { effect -> [Float] in
            switch effect {
            case .rattle:
                // Dice shaken in the hand as they leave it: quick knocks of bone on bone.
                var rattle = silence(0.3)
                for i in 0..<7 {
                    let pitch = 0.85 + 0.35 * random.unit()
                    let at = 0.025 * Double(i) + 0.015 * random.unit()
                    let gain = Float(0.3 + 0.6 * random.unit())
                    add(knock(seed: UInt32(40 + i), pitch: pitch), to: &rattle, at: at, gain: gain)
                }
                return normalized(rattle, peak: 0.35)
            case .die:
                // A die striking the board: a hard click and the wood answering under it.
                return normalized(strike(length: 0.13, modes: [(2150, 0.55, 0.004), (3900, 0.3, 0.002), (760, 0.45, 0.014), (330, 0.35, 0.024)],
                                         click: 1.1, clickDecay: 0.0008, brightness: 0.7, seed: 5), peak: 0.6)
            case .checker:
                // A checker set down on the board: a short, woody knock.
                return normalized(strike(length: 0.14, modes: [(980, 0.6, 0.009), (1720, 0.32, 0.004), (440, 0.42, 0.018), (260, 0.25, 0.026)],
                                         click: 0.8, clickDecay: 0.0012, brightness: 0.5, seed: 7), peak: 0.55)
            case .hit:
                // A lone checker knocked off: the clack of checker on checker over the knock on the board.
                var hit = strike(length: 0.14, modes: [(980, 0.5, 0.009), (440, 0.35, 0.018)], click: 0.7, clickDecay: 0.0012, brightness: 0.5,
                                 seed: 9)
                add(knock(seed: 11, pitch: 0.62), to: &hit, at: 0, gain: 1.3)
                return normalized(hit, peak: 0.65)
            case .tray:
                // A checker dropped into the felt of the tray: a dull thud.
                return normalized(strike(length: 0.2, modes: [(190, 0.8, 0.022), (360, 0.4, 0.012), (760, 0.15, 0.006)], click: 0.45,
                                         clickDecay: 0.006, brightness: 0.15, seed: 13), peak: 0.5)
            case .setup:
                // The checkers set out for a new game: one after another onto the board.
                var setup = silence(0.6)
                for i in 0..<10 {
                    let frequency = 980 * (0.92 + 0.16 * random.unit())
                    let at = 0.045 * Double(i) + 0.02 * random.unit()
                    let gain = Float(0.35 + 0.5 * random.unit())
                    add(strike(length: 0.1, modes: [(frequency, 0.6, 0.008), (440, 0.4, 0.016)], click: 0.7, clickDecay: 0.001, brightness: 0.5,
                               seed: UInt32(60 + i)), to: &setup, at: at, gain: gain)
                }
                return normalized(setup, peak: 0.4)
            case .click:
                let click = (0..<Int(0.03 * rate)).map { i -> Float in
                    let t = Double(i) / rate
                    return Float(sin(2 * Double.pi * 2600 * t) * exp(-t / 0.004))
                }
                return normalized(click, peak: 0.18)
            case .noMove:
                var noMove = silence(0.9)
                add(bell(frequency: 392.0, length: 0.6), to: &noMove, at: 0, gain: 1)
                add(bell(frequency: 311.1, length: 0.7), to: &noMove, at: 0.16, gain: 1)
                return normalized(noMove, peak: 0.2)
            case .win:
                var chord = silence(1.8)
                for (index, note) in [523.25, 659.25, 783.99, 1046.5].enumerated() {
                    add(bell(frequency: note, length: 1.5), to: &chord, at: Double(index) * 0.11, gain: 0.8)
                }
                return normalized(chord, peak: 0.35)
            }
        }
    }

    // MARK: - Making sounds

    /// A minimal standard generator, as the noise of the original was made with.
    private struct MinimalRandom {
        private var state: UInt64

        init(seed: UInt32) {
            let s = UInt64(seed) % 2_147_483_647
            state = s == 0 ? 1 : s
        }

        /// In [0, 1).
        mutating func unit() -> Double {
            state = state * 48_271 % 2_147_483_647
            return Double(state - 1) / 2_147_483_646
        }
    }

    private static func silence(_ seconds: Double) -> [Float] { [Float](repeating: 0, count: Int(seconds * rate)) }

    private static func add(_ source: [Float], to target: inout [Float], at seconds: Double, gain: Float) {
        let offset = Int(seconds * rate)
        if target.count < offset + source.count {
            target += [Float](repeating: 0, count: offset + source.count - target.count)
        }
        for (i, sample) in source.enumerated() {
            target[offset + i] += sample * gain
        }
    }

    /// Scaled so that the loudest sample is `peak`.
    private static func normalized(_ samples: [Float], peak: Float) -> [Float] {
        let loudest = samples.reduce(Float(1e-6)) { max($0, abs($1)) }
        return samples.map { $0 * peak / loudest }
    }

    /// A struck body: a burst of noise, the higher part of it for a hard click, and damped resonances, each a frequency
    /// (Hz), an amplitude and the seconds it takes to fall to 1/e.
    private static func strike(length: Double, modes: [(frequency: Double, gain: Double, decay: Double)], click: Double, clickDecay: Double,
                               brightness: Double, seed: UInt32) -> [Float] {
        var random = MinimalRandom(seed: seed)
        var low: Float = 0
        return (0..<Int(length * rate)).map { i -> Float in
            let t = Double(i) / rate
            let white = Float(random.unit() * 2 - 1)
            low += (white - low) * 0.08
            let bright = white - low
            var value = click * (brightness * Double(bright) + (1 - brightness) * 3 * Double(low)) * exp(-t / clickDecay)
            for mode in modes {
                value += mode.gain * sin(2 * Double.pi * mode.frequency * t) * exp(-t / mode.decay)
            }
            return Float(value * min(1, t / 0.0003))
        }
    }

    /// Two hard little bodies knocking together: a die on a die, a checker on a checker.
    private static func knock(seed: UInt32, pitch: Double) -> [Float] {
        strike(length: 0.07, modes: [(2900 * pitch, 0.8, 0.004), (4700 * pitch, 0.45, 0.002), (1700 * pitch, 0.3, 0.006)], click: 1.3,
               clickDecay: 0.0006, brightness: 0.85, seed: seed)
    }

    /// A small bell: inharmonic partials dying away at their own rates.
    private static func bell(frequency: Double, length: Double) -> [Float] {
        let partials: [(ratio: Double, gain: Double, decay: Double)] = [(1.0, 1.0, 1.0), (2.0, 0.45, 0.6), (2.76, 0.3, 0.4), (5.4, 0.12, 0.25)]
        return (0..<Int(length * rate)).map { i -> Float in
            let t = Double(i) / rate
            var value = 0.0
            for partial in partials {
                value += partial.gain * sin(2 * Double.pi * frequency * partial.ratio * t) * exp(-t / (length * 0.35 * partial.decay))
            }
            return Float(value * min(1, t / 0.004))
        }
    }
}
