import Foundation
import simd

/// How the checkers and the dice are shown: every checker in its place, flying in an arc when it moves, lifted when
/// chosen or dragged; and the dice thrown onto the board, tumbling and coming to rest on the numbers rolled.
struct BoardView {
    /// What was heard since the last call: checkers landing, knocking a lone one off or dropping into the tray, and
    /// the dice striking the board, each as loud as it strikes.
    struct Sounds {
        var landings = 0
        var hits = 0
        var trays = 0
        var dice: [Float] = []
    }

    private struct Checker {
        var side = 0
        var place = 0
        /// The flight.
        var from = SIMD3<Float>(repeating: 0)
        var to = SIMD3<Float>(repeating: 0)
        var time: Float = 1
        var duration: Float = 1
        var delay: Float = 0
        /// Raised when chosen.
        var lift: Float = 0
        /// 1 if it starts its flight standing in the tray.
        var standFrom: Float = 0
        var hitOnArrival = false
    }

    private struct Die {
        var visible = false
        var side = 0
        var value = 1
        var from = SIMD3<Float>(repeating: 0)
        var to = SIMD3<Float>(repeating: 0)
        /// The quaternion it comes to rest in.
        var rest = SIMD4<Float>(0, 0, 0, 1)
        var spinAxis = SIMD3<Float>(0, 1, 0)
        var spin: Float = 0
        var time: Float = 1
        var duration: Float = 1
        var dim: Float = 0
        var dimTarget: Float = 0
    }

    /// A place for checkers: a point (as White counts them), the bar, or the tray.
    static let barPlace = 24
    static let offPlace = 25
    static let places = 26

    /// The stages of a die's flight where it strikes the board, and how loud.
    private static let contacts: [Float] = [0.182, 0.545, 0.909]
    private static let contactVolumes: [Float] = [1.0, 0.55, 0.3]

    private var checkers = [Checker](repeating: Checker(), count: 2 * Nardy.checkers)
    /// The checkers at each place of each side, by their number, bottom first.
    private var stacks = [[[Int]]](repeating: [[Int]](repeating: [], count: places), count: 2)
    private var dice = [Die(), Die()]
    private var liftedSide = -1
    private var liftedPlace = -1
    private var carried: SIMD3<Float>?
    private var sounds = Sounds()

    /// Every checker in its place at once; `board` is seen from White's side.
    mutating func reset(_ board: Position) {
        stacks = [[[Int]]](repeating: [[Int]](repeating: [], count: Self.places), count: 2)
        var next = 0
        func add(_ side: Int, _ place: Int, _ count: Int) {
            for _ in 0..<count where next < checkers.count {
                var c = Checker()
                c.side = side
                c.place = place
                c.from = spot(side, place, stacks[side][place].count)
                c.to = c.from
                c.standFrom = place == Self.offPlace ? 1 : 0
                checkers[next] = c
                stacks[side][place].append(next)
                next += 1
            }
        }
        for w in 0..<Nardy.points {
            let n = Int(board.points[w])
            add(n > 0 ? 0 : 1, w, abs(n))
        }
        for side in 0..<2 {
            add(side, Self.barPlace, Int(board.bar[side]))
            add(side, Self.offPlace, Int(board.off[side]))
        }
        liftedSide = -1
        liftedPlace = -1
        carried = nil
    }

    /// The top checker of `side` at `from` goes to `to`, after `delay` seconds; a lone checker hit there goes to the
    /// bar.
    mutating func move(side: Int, from: Int, to: Int, delay: Float = 0) {
        guard let id = stacks[side][from].last else { return }
        // It flies from where it is drawn now: carried, raised, or still on its way there.
        let start = carried != nil && side == liftedSide && from == liftedPlace ? carried! : topOf(side, from)
        stacks[side][from].removeLast()
        // Where it rests, and how long it flies.
        var c = checkers[id]
        c.from = start
        c.standFrom = from == Self.offPlace ? 1 : 0
        c.to = spot(side, to, stacks[side][to].count)
        c.place = to
        c.time = 0
        c.delay = delay
        c.duration = 0.3 + 0.35 * min(1, length(c.to - c.from) / 0.5)
        c.lift = 0
        c.hitOnArrival = false
        stacks[side][to].append(id)
        if side == liftedSide && from == liftedPlace {
            liftedSide = -1
            liftedPlace = -1
        }
        carried = nil

        // A lone checker of the other side there is knocked to the bar as this one arrives.
        if to < Nardy.points, let hit = stacks[1 - side][to].last {
            var h = checkers[hit]
            h.from = topOf(1 - side, to)
            stacks[1 - side][to].removeLast()
            h.standFrom = 0
            h.to = spot(1 - side, Self.barPlace, stacks[1 - side][Self.barPlace].count)
            h.place = Self.barPlace
            h.time = 0
            h.delay = delay + c.duration * 0.85
            h.duration = 0.45
            checkers[hit] = h
            stacks[1 - side][Self.barPlace].append(hit)
            c.hitOnArrival = true
        }
        checkers[id] = c
    }

    /// A checker raised over its place, as chosen; nothing raised for a side of -1.
    mutating func lift(side: Int, place: Int) {
        liftedSide = side
        liftedPlace = place
    }

    /// The raised checker carried by the pointer, or set down again.
    mutating func carry(_ position: SIMD3<Float>?) {
        carried = position
    }

    /// Two dice thrown by `side`.
    mutating func throwDice(side: Int, first: Int, second: Int, random: inout RandomSource) {
        // From the thrower's hand, at their side of the board, into their right half.
        let z: Float = side == 0 ? 0.32 : -0.32
        let x: Float = side == 0 ? 0.16 : -0.16
        dice[0] = Self.thrownDie(side: side, index: 0, value: first, from: SIMD3(x - 0.02, 0.16, z), random: &random)
        dice[1] = Self.thrownDie(side: side, index: 1, value: second, from: SIMD3(x + 0.03, 0.18, z + (side == 0 ? 0.02 : -0.02)), random: &random)
        dice[1].duration += 0.06
    }

    /// One die each for the two players, to see who starts.
    mutating func throwOpening(white: Int, black: Int, random: inout RandomSource) {
        dice[0] = Self.thrownDie(side: 0, index: 0, value: white, from: SIMD3(0.16, 0.16, 0.32), random: &random)
        dice[1] = Self.thrownDie(side: 1, index: 0, value: black, from: SIMD3(-0.16, 0.16, -0.32), random: &random)
    }

    /// Two dice of `side` lying still on the numbers given, as a turn taken back left them.
    mutating func showDice(side: Int, first: Int, second: Int) {
        var random = RandomSource(seed: UInt64(first * 7 + second))
        throwDice(side: side, first: first, second: second, random: &random)
        for index in dice.indices {
            dice[index].time = dice[index].duration
        }
    }

    mutating func clearDice() {
        dice = [Die(), Die()]
    }

    /// How many of the roll's steps are played: the dice darken as they are used. `firstUsed` is the die the first
    /// step played, 0 or 1.
    mutating func useDice(_ used: Int, doubles: Bool, firstUsed: Int) {
        // Two different dice darken one by one; a double's pair after two steps each.
        if doubles {
            dice[0].dimTarget = used >= 2 ? 1 : 0
            dice[1].dimTarget = used >= 4 ? 1 : 0
        } else {
            dice[0].dimTarget = used >= 2 || (used == 1 && firstUsed == 0) ? 1 : 0
            dice[1].dimTarget = used >= 2 || (used == 1 && firstUsed == 1) ? 1 : 0
        }
    }

    mutating func update(_ seconds: Float) {
        for id in checkers.indices {
            var c = checkers[id]
            if c.time < 1 {
                if c.delay > 0 {
                    c.delay -= seconds
                } else {
                    c.time = min(1, c.time + seconds / c.duration)
                    if c.time >= 1 {
                        if c.hitOnArrival {
                            sounds.hits += 1
                        } else if c.place == Self.offPlace {
                            sounds.trays += 1
                        } else {
                            sounds.landings += 1
                        }
                    }
                }
            }
            c.lift += ((isLifted(id) ? 1 : 0) - c.lift) * (1 - exp(-seconds * 18))
            checkers[id] = c
        }
        for index in dice.indices where dice[index].visible {
            var die = dice[index]
            if die.time < die.duration {
                let before = die.time / die.duration
                die.time = min(die.duration, die.time + seconds)
                let after = die.time / die.duration
                for (contact, volume) in zip(Self.contacts, Self.contactVolumes) where before < contact && after >= contact {
                    sounds.dice.append(volume)
                }
            }
            die.dim += (die.dimTarget - die.dim) * (1 - exp(-seconds * 10))
            dice[index] = die
        }
    }

    var isAnimating: Bool {
        for id in checkers.indices {
            let c = checkers[id]
            if c.time < 1 || abs((isLifted(id) ? 1 : 0) - c.lift) > 0.002 {
                return true
            }
        }
        return dice.contains { $0.visible && ($0.time < $0.duration || abs($0.dim - $0.dimTarget) > 0.002) }
    }

    var diceRolling: Bool { dice.contains { $0.visible && $0.time < $0.duration } }

    mutating func takeSounds() -> Sounds {
        defer { sounds = Sounds() }
        return sounds
    }

    /// The checkers and the dice to draw; the top checkers of `glowSide` glow as `glow` says for their places.
    func pieces(glow: [Float], glowSide: Int) -> [PieceDraw] {
        var pieces: [PieceDraw] = []
        for side in 0..<2 {
            for place in 0..<Self.places {
                let stack = stacks[side][place]
                for (k, id) in stack.enumerated() {
                    let c = checkers[id]
                    var piece = PieceDraw()
                    piece.model = checkerModel(id)
                    piece.side = side
                    let top = k + 1 == stack.count
                    piece.highlight = max(top && c.time >= 1 && side == glowSide ? glow[place] : 0, c.lift)
                    pieces.append(piece)
                }
            }
        }
        for die in dice where die.visible {
            let s = die.time / die.duration
            // Fast spin at first, slowing as it settles on the face rolled.
            let spinLeft = pow(1 - s, 3)
            let rotation = Matrix.rotation(Self.multiply(die.rest, Self.axisAngle(die.spinAxis, die.spin * spinLeft)))
            let extent = Board.dieSize * (abs(rotation.columns.0.y) + abs(rotation.columns.1.y) + abs(rotation.columns.2.y))
            let travel = 1 - pow(1 - s, 2.2)
            let bounce = die.from.y * (1 - s) * (1 - s) * abs(cos(s * Float.pi * 2.75))
            var p = die.from + (die.to - die.from) * travel
            p.y = max(extent * 0.92, Board.dieSize) + bounce
            var piece = PieceDraw()
            piece.model = Matrix.translation(p) * rotation * Matrix.scale(Board.dieSize)
            piece.kind = .die
            piece.side = die.side
            piece.value = die.value
            piece.dim = die.dim
            pieces.append(piece)
        }
        return pieces
    }

    // MARK: - Helpers

    private func spot(_ side: Int, _ place: Int, _ index: Int) -> SIMD3<Float> {
        switch place {
        case Self.barPlace: Board.barSpot(side: side, index)
        case Self.offPlace: Board.offSpot(side: side, index)
        default: Board.checkerSpot(place, index)
        }
    }

    /// Whether the checker is the top one of the place raised.
    private func isLifted(_ id: Int) -> Bool {
        let c = checkers[id]
        return c.side == liftedSide && c.place == liftedPlace && stacks[c.side][c.place].last == id
    }

    /// Where the top checker of a place is drawn now, in flight or not.
    private func topOf(_ side: Int, _ place: Int) -> SIMD3<Float> {
        guard let id = stacks[side][place].last else { return spot(side, place, 0) }
        let model = checkerModel(id)
        return SIMD3(model.columns.3.x, model.columns.3.y, model.columns.3.z)
    }

    private func checkerModel(_ id: Int) -> float4x4 {
        let c = checkers[id]
        // In flight: along an arc that rises with the distance; standing on edge in the tray.
        let s = Easing.smoothStep(0, 1, c.time)
        let distance = length(c.to - c.from)
        let arc = min(0.12, 0.025 + 0.12 * distance)
        var p = c.from + (c.to - c.from) * s + SIMD3(0, arc * 4 * s * (1 - s), 0)
        p.y += c.lift * 0.014
        // Only the top checker of the place is carried.
        if let carried, c.side == liftedSide, c.place == liftedPlace, c.time >= 1, stacks[c.side][c.place].last == id {
            p = carried
        }
        let stand = c.standFrom + ((c.place == Self.offPlace ? 1 : 0) - c.standFrom) * s
        return Matrix.translation(p) * Matrix.rotationX(stand * Float.pi / 2) * Matrix.scale(Board.checkerRadius)
    }

    private static func thrownDie(side: Int, index: Int, value: Int, from: SIMD3<Float>, random: inout RandomSource) -> Die {
        func unit() -> Float { Float(random.uniform(-1, 1)) }
        var die = Die()
        die.visible = true
        die.side = side
        die.value = value
        die.from = from
        let jitterX = unit() * 0.008
        let jitterZ = unit() * 0.006
        die.to = Board.dieSpot(side: side, index) + SIMD3(jitterX, 0, jitterZ)
        die.rest = multiply(axisAngle(SIMD3(0, 1, 0), unit() * 0.5), faceUp(value))
        let axisX = unit()
        let axisY = unit() * 0.4
        let axisZ = unit()
        die.spinAxis = Matrix.unit(SIMD3(axisX, axisY, axisZ) + SIMD3(0.3, 0, 0.3))
        die.spin = 2 * Float.pi * (2.2 + unit() * 0.6)
        die.duration = 0.95 + 0.12 * unit()
        die.time = 0
        return die
    }

    // MARK: - Quaternions, as (x, y, z, w)

    private static func axisAngle(_ axis: SIMD3<Float>, _ angle: Float) -> SIMD4<Float> {
        let s = sin(angle / 2)
        return SIMD4(axis.x * s, axis.y * s, axis.z * s, cos(angle / 2))
    }

    private static func multiply(_ a: SIMD4<Float>, _ b: SIMD4<Float>) -> SIMD4<Float> {
        SIMD4(a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
              a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
              a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
              a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z)
    }

    /// The turn that brings the face with `value` to the top. The die's faces: 1 on +y, 2 on +z, 3 on +x, and the
    /// opposite faces adding up to seven.
    private static func faceUp(_ value: Int) -> SIMD4<Float> {
        let h = Float(0.5).squareRoot()
        switch value {
        case 2: return SIMD4(-h, 0, 0, h)
        case 3: return SIMD4(0, 0, h, h)
        case 4: return SIMD4(0, 0, -h, h)
        case 5: return SIMD4(h, 0, 0, h)
        case 6: return SIMD4(1, 0, 0, 0)
        default: return SIMD4(0, 0, 0, 1)
        }
    }
}
