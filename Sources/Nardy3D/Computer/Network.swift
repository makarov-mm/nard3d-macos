import Foundation

/// A small neural network that judges positions, taught by playing against itself (temporal-difference learning, as
/// TD-Gammon was): the checkers of both sides on each point, on the bar and borne off, and the pips left, through one
/// hidden layer to the three chances of a `Value`. Its weights come with the program, one file for each game.
struct Network: Sendable {
    private struct Input {
        var index: Int
        var value: Float
    }

    static let inputs = 200
    static let hidden = 64
    static let outputs = 3

    /// An input's weights to every hidden unit together.
    private let hiddenWeights: [Float]
    private let hiddenBias: [Float]
    /// A hidden unit's weights to every output together.
    private let outputWeights: [Float]
    private let outputBias: [Float]

    /// The weights as the file keeps them: "NRD1", the three sizes of the layers as 32-bit integers, then the weights
    /// to the hidden layer, its biases, the weights to the outputs and their biases, all little-endian.
    init?(data: Data) {
        let bytes = [UInt8](data)
        let floats = Self.inputs * Self.hidden + Self.hidden + Self.hidden * Self.outputs + Self.outputs
        guard bytes.count == 16 + floats * 4, bytes.prefix(4).elementsEqual("NRD1".utf8) else { return nil }
        func word(_ offset: Int) -> UInt32 {
            (0..<4).reduce(UInt32(0)) { $0 | UInt32(bytes[offset + $1]) << (8 * $1) }
        }
        guard Int(word(4)) == Self.inputs, Int(word(8)) == Self.hidden, Int(word(12)) == Self.outputs else { return nil }
        var offset = 16
        func read(_ count: Int) -> [Float] {
            let part = (0..<count).map { Float(bitPattern: word(offset + 4 * $0)) }
            offset += 4 * count
            return part
        }
        hiddenWeights = read(Self.inputs * Self.hidden)
        hiddenBias = read(Self.hidden)
        outputWeights = read(Self.hidden * Self.outputs)
        outputBias = read(Self.outputs)
    }

    func evaluate(_ position: Position, _ variant: Variant) -> Value {
        var hidden = hiddenBias
        for input in Self.encode(position, variant) {
            let base = input.index * Self.hidden
            for j in 0..<Self.hidden {
                hidden[j] += hiddenWeights[base + j] * input.value
            }
        }
        for j in 0..<Self.hidden {
            hidden[j] = Self.sigmoid(hidden[j])
        }
        var output = [Float](repeating: 0, count: Self.outputs)
        for o in 0..<Self.outputs {
            var sum = outputBias[o]
            for j in 0..<Self.hidden {
                sum += hidden[j] * outputWeights[j * Self.outputs + o]
            }
            output[o] = Self.sigmoid(sum)
        }
        // A gammon is a win too: its chance cannot be above the win's.
        return Value(win: output[0], winGammon: min(output[1], output[0]), loseGammon: min(output[2], 1 - output[0]))
    }

    /// The inputs that are not zero: for every point four for each side (one checker, two, three, and the rest), then
    /// the bar, the checkers borne off, the pips left and whether each side may bear off.
    private static func encode(_ p: Position, _ variant: Variant) -> [Input] {
        var inputs: [Input] = []
        inputs.reserveCapacity(112)
        func add(_ index: Int, _ value: Float) {
            if value != 0 {
                inputs.append(Input(index: index, value: value))
            }
        }
        for i in 0..<Nardy.points {
            let n = Int(p.points[i])
            let base = i * 8 + (n > 0 ? 0 : 4)
            let m = abs(n)
            add(base, m >= 1 ? 1 : 0)
            add(base + 1, m >= 2 ? 1 : 0)
            add(base + 2, m >= 3 ? 1 : 0)
            add(base + 3, m > 3 ? Float(m - 3) * 0.5 : 0)
        }
        let startPips: Float = variant == .long ? 360 : 167
        add(192, Float(p.bar[0]) * 0.5)
        add(193, Float(p.bar[1]) * 0.5)
        add(194, Float(p.off[0]) / 15)
        add(195, Float(p.off[1]) / 15)
        add(196, Float(Nardy.pips(p, side: 0, variant)) / startPips)
        add(197, Float(Nardy.pips(p, side: 1, variant)) / startPips)
        // Whether each side has every checker home.
        let flipped = Nardy.flip(p, variant)
        let mine = p.bar[0] == 0 && (6..<Nardy.points).allSatisfy { p.points[$0] <= 0 }
        let theirs = p.bar[1] == 0 && (6..<Nardy.points).allSatisfy { flipped.points[$0] <= 0 }
        add(198, mine ? 1 : 0)
        add(199, theirs ? 1 : 0)
        return inputs
    }

    private static func sigmoid(_ x: Float) -> Float { 1 / (1 + exp(-x)) }
}
