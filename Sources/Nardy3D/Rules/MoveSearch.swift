/// The search for the ways to play a roll: every order of steps the dice allow, from which the legal moves are
/// picked. For the computer each position is reached once, by one order of steps; for a person every order is kept.
struct MoveSearch {
    private let variant: Variant
    /// Each position once, for the computer; every order, for a person.
    private let distinct: Bool
    /// How many checkers may leave the head of long nardy this turn.
    private let headLimit: Int
    /// The dice of the roll; the first `left` of them are still to play.
    private var dice: [Int]
    /// Every prefix of every order of steps, as a candidate.
    private var nodes: [Move] = []
    private var seen = SeenSet()
    private var current = Move()

    private init(variant: Variant, distinct: Bool, headLimit: Int, dice: [Int]) {
        self.variant = variant
        self.distinct = distinct
        self.headLimit = headLimit
        self.dice = dice
        nodes.reserveCapacity(256)
    }

    static func collect(_ position: Position, _ variant: Variant, _ roll: Roll, firstMove: Bool, distinct: Bool) -> [Move] {
        let doubleOffHead = firstMove && roll.isDouble && [6, 4, 3].contains(roll.first)
        let headLimit = variant == .short ? 4 : doubleOffHead ? 2 : 1
        var search = MoveSearch(variant: variant, distinct: distinct, headLimit: headLimit,
                                dice: [roll.first, roll.second, roll.first, roll.first])
        search.explore(position, left: roll.isDouble ? 4 : 2, headMoves: 0)

        // As many dice as can be played, by moves that keep to the block rule.
        func valid(_ move: Move) -> Bool { variant == .short || Nardy.blockAllowed(move.after) }
        var longest = 0
        for move in search.nodes where move.count > longest && valid(move) {
            longest = move.count
        }
        if longest == 0 {
            return []
        }
        var moves = search.nodes.filter { $0.count == longest && valid($0) }
        // When only one die can be played, the higher one if it can.
        if longest == 1 && !roll.isDouble {
            let higher = max(roll.first, roll.second)
            if moves.contains(where: { $0.steps[0].die == higher }) {
                moves.removeAll { $0.steps[0].die != higher }
            }
        }
        if distinct {
            search.seen.clear()
            moves = moves.filter { search.seen.insert(hash($0.after, 0xFFFF)) }
        }
        return moves
    }

    /// Every way of playing the dice still left from `p`, each prefix kept as a candidate.
    private mutating func explore(_ p: Position, left: Int, headMoves: Int) {
        current.after = p
        nodes.append(current)
        for k in 0..<left {
            let die = dice[k]
            if dice[0..<k].contains(die) {
                continue
            }
            let steps = Self.steps(p, variant, die: die)
            if steps.isEmpty {
                continue
            }
            // The die taken out of the ones left: the others stay in front.
            dice.swapAt(k, left - 1)
            for step in steps {
                let fromHead = variant == .long && step.from == Nardy.head ? 1 : 0
                if headMoves + fromHead > headLimit {
                    continue
                }
                let next = Nardy.apply(p, step)
                if distinct && !seen.insert(Self.hash(next, Self.key(dice, left: left - 1, headMoves: headMoves + fromHead))) {
                    continue
                }
                current.steps.append(step)
                explore(next, left: left - 1, headMoves: headMoves + fromHead)
                current.steps.removeLast()
            }
            dice.swapAt(k, left - 1)
        }
    }

    /// The single steps the mover can make with one die.
    private static func steps(_ p: Position, _ variant: Variant, die: Int) -> [Step] {
        if variant == .short && p.bar[0] > 0 {
            // Checkers on the bar enter first, into the opponent's home.
            let to = Nardy.fromBar - die
            let there = p.points[to]
            return there >= -1 ? [Step(from: Nardy.fromBar, to: to, die: die, hit: there == -1)] : []
        }
        var highest = -1
        for i in stride(from: Nardy.points - 1, through: 0, by: -1) where p.points[i] > 0 {
            highest = i
            break
        }
        let home = highest < 6
        var steps: [Step] = []
        for from in stride(from: highest, through: 0, by: -1) where p.points[from] > 0 {
            let to = from - die
            if to >= 0 {
                let there = p.points[to]
                if variant == .long ? there >= 0 : there >= -1 {
                    steps.append(Step(from: from, to: to, die: die, hit: variant == .short && there == -1))
                }
            } else if home && (to == Nardy.bearOff || from == highest) {
                // Off exactly, or from the farthest checker with a die larger than it needs.
                steps.append(Step(from: from, to: Nardy.bearOff, die: die))
            }
        }
        return steps
    }

    /// What is left to play: how many dice, the lowest and the highest of them, and the checkers already off the head.
    private static func key(_ dice: [Int], left: Int, headMoves: Int) -> UInt32 {
        var low = 7
        var high = 0
        for k in 0..<left {
            low = min(low, dice[k])
            high = max(high, dice[k])
        }
        return UInt32(left | low << 3 | high << 6 | headMoves << 9)
    }

    /// FNV-1a over the position, after `extra`.
    private static func hash(_ p: Position, _ extra: UInt32) -> UInt64 {
        var hash = 1_469_598_103_934_665_603 ^ UInt64(extra)
        func mix(_ value: Int8) {
            hash ^= UInt64(UInt8(bitPattern: value))
            hash &*= 1_099_511_628_211
        }
        for i in 0..<Nardy.points {
            mix(p.points[i])
        }
        mix(p.bar[0])
        mix(p.bar[1])
        mix(p.off[0])
        mix(p.off[1])
        return hash
    }
}
