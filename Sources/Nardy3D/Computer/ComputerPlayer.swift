/// The computer player. It judges by the network the position each way of playing the roll leaves; at the top level
/// it also weighs every roll the opponent may answer with and their best reply. The lower levels misjudge on purpose,
/// the lowest by much.
enum ComputerPlayer {
    /// How far off each level's judgement is, in points.
    private static let noise: [Float] = [0, 0.45, 0.22, 0.08, 0, 0]
    /// The moves the strongest level looks further at.
    private static let considered = 8

    /// The move to play: one of the legal moves, or none when nothing can be played. `opponentFirst` says whether
    /// the opponent's next turn is their first.
    static func choose(net: Network, position: Position, variant: Variant, roll: Roll, firstMove: Bool, opponentFirst: Bool, level: Int,
                       seed: UInt64, stop: StopFlag) -> Move {
        let moves = Nardy.legalMoves(position, variant, roll, firstMove: firstMove)
        if moves.isEmpty {
            return Move(after: position)
        }
        var random = RandomSource(seed: seed)
        let level = min(max(level, 1), 5)
        let noise = Self.noise[level]
        if level <= 1 && random.next() % 4 == 0 {
            return moves[random.below(moves.count)]
        }

        // Best first; of equal ones, the later in the list.
        var ranked = moves.indices.map { index -> (value: Float, index: Int) in
            let error = noise > 0 ? Float(random.normal(deviation: Double(noise))) : 0
            return (judge(net, moves[index], variant) + error, index)
        }
        ranked.sort { $0.value != $1.value ? $0.value > $1.value : $0.index > $1.index }
        if level < 5 || moves.count == 1 {
            return moves[ranked[0].index]
        }

        // The strongest level looks one roll further at the most promising few.
        var best: Float = -1e9
        var chosen = ranked[0].index
        for candidate in ranked.prefix(considered) {
            if stop.isRaised {
                break
            }
            let value = lookAhead(net, moves[candidate.index], variant, opponentFirst: opponentFirst, stop: stop)
            if value > best {
                best = value
                chosen = candidate.index
            }
        }
        return moves[chosen]
    }

    /// The worth to the mover of where a move leaves the board, in points.
    private static func judge(_ net: Network, _ move: Move, _ variant: Variant) -> Float {
        if Int(move.after.off[0]) == Nardy.checkers {
            return Float(Nardy.winPoints(move.after, variant))
        }
        return net.evaluate(Nardy.flip(move.after, variant), variant).flipped.equity
    }

    /// The worth to the mover of a move, averaged over the opponent's rolls and their best answer to each.
    private static func lookAhead(_ net: Network, _ move: Move, _ variant: Variant, opponentFirst: Bool, stop: StopFlag) -> Float {
        if Int(move.after.off[0]) == Nardy.checkers {
            return Float(Nardy.winPoints(move.after, variant))
        }
        let theirs = Nardy.flip(move.after, variant)
        var total: Float = 0
        for a in 1...6 {
            for b in a...6 {
                if stop.isRaised {
                    return 0
                }
                let weight: Float = a == b ? 1.0 / 36 : 2.0 / 36
                let replies = Nardy.legalMoves(theirs, variant, Roll(first: a, second: b), firstMove: opponentFirst)
                let best: Float
                if replies.isEmpty {
                    // They cannot move: the mover is to play again.
                    best = -net.evaluate(move.after, variant).equity
                } else {
                    best = replies.reduce(-1e9) { max($0, judge(net, $1, variant)) }
                }
                total -= weight * best
            }
        }
        return total
    }
}
