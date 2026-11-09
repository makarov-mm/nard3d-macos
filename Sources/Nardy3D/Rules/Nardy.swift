/// The rules of the two games of nardy. In long nardy both sides run the same way round the board, a single checker
/// holds a point, only one checker a turn may leave the head, and no six points in a row may be held while they shut
/// the opponent in. In short nardy (backgammon) the sides run against each other, and a lone checker is hit to the
/// bar and must enter again.
enum Nardy {
    static let points = 24
    static let checkers = 15
    /// Where long nardy starts all fifteen.
    static let head = 23
    /// A step entering from the bar.
    static let fromBar = 24
    /// A step bearing a checker off.
    static let bearOff = -1

    static func start(_ variant: Variant) -> Position {
        var p = Position()
        switch variant {
        case .long:
            p.points[head] = Int8(checkers)
            p.points[11] = -Int8(checkers)
        case .short:
            p.points[23] = 2
            p.points[12] = 5
            p.points[7] = 3
            p.points[5] = 5
            p.points[0] = -2
            p.points[11] = -5
            p.points[16] = -3
            p.points[18] = -5
        }
        return p
    }

    /// The same position seen by the other player.
    static func flip(_ p: Position, _ variant: Variant) -> Position {
        // Short nardy is a mirror; in long nardy the opponent's start lies half way round from the mover's.
        var q = Position()
        for i in 0..<points {
            let j = variant == .short ? points - 1 - i : (i + 12) % points
            q.points[i] = -p.points[j]
        }
        q.bar = SIMD2(p.bar[1], p.bar[0])
        q.off = SIMD2(p.off[1], p.off[0])
        return q
    }

    static func apply(_ p: Position, _ step: Step) -> Position {
        var q = p
        if step.from == fromBar {
            q.bar[0] -= 1
        } else {
            q.points[step.from] -= 1
        }
        if step.to == bearOff {
            q.off[0] += 1
        } else {
            if q.points[step.to] < 0 {
                // Only a lone checker can be there to hit.
                q.points[step.to] = 0
                q.bar[1] += 1
            }
            q.points[step.to] += 1
        }
        return q
    }

    /// The pips the mover (side 0) or the opponent (side 1) still has to travel.
    static func pips(_ position: Position, side: Int, _ variant: Variant) -> Int {
        let p = side == 0 ? position : flip(position, variant)
        var pips = Int(p.bar[0]) * 25
        for i in 0..<points where p.points[i] > 0 {
            pips += Int(p.points[i]) * (i + 1)
        }
        return pips
    }

    /// Long nardy: the mover holds no six points in a row unless an opponent's checker has already passed them.
    static func blockAllowed(_ p: Position) -> Bool {
        // The points in the order the opponent passes them: their last point is the mover's 12, their head the
        // mover's 11.
        func at(_ o: Int) -> Int8 { p.points[(o + 12) % points] }
        var firstOpponent = points
        for o in 0..<points where at(o) < 0 {
            firstOpponent = o
            break
        }
        var run = 0
        for o in 0..<points {
            run = at(o) > 0 ? run + 1 : 0
            // Six in a row from o - run + 1: allowed only with an opponent's checker already past its start.
            if run >= 6 && firstOpponent >= o - run + 1 {
                return false
            }
        }
        return true
    }

    /// The ways to play a roll, each final position once, with one order of steps that reaches it. As many dice as
    /// possible must be played, and the higher one when only one can be. `firstMove` lets two checkers leave the head
    /// of long nardy on a first roll of 6-6, 4-4 or 3-3. Empty when nothing can be played.
    static func legalMoves(_ position: Position, _ variant: Variant, _ roll: Roll, firstMove: Bool) -> [Move] {
        MoveSearch.collect(position, variant, roll, firstMove: firstMove, distinct: true)
    }

    /// Every order of steps that plays the roll legally, for a player choosing step by step.
    static func legalSequences(_ position: Position, _ variant: Variant, _ roll: Roll, firstMove: Bool) -> [Move] {
        MoveSearch.collect(position, variant, roll, firstMove: firstMove, distinct: false)
    }

    /// After the mover has borne off their last checker: 1, 2 for a gammon (марс), or 3 for a backgammon (кокс).
    static func winPoints(_ p: Position, _ variant: Variant) -> Int {
        if p.off[1] > 0 {
            return 1
        }
        if variant == .long {
            return 2
        }
        // A backgammon: the loser still has a checker on the bar or in the winner's home.
        var deep = p.bar[1] > 0
        for i in 0..<6 where p.points[i] < 0 {
            deep = true
        }
        return deep ? 3 : 2
    }
}
