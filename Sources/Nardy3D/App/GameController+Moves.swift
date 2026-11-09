/// The steps a person may take with the checkers, the words for a turn, and a game in progress kept as text.
extension GameController {
    /// The steps that may be played next.
    func nextSteps() -> [Step] {
        var steps: [Step] = []
        let k = played.count
        for move in sequences where move.count > k && move.steps.starts(with: played) {
            let next = move.steps[k]
            if !steps.contains(next) {
                steps.append(next)
            }
        }
        return steps
    }

    /// Where the checker on `point`, in the mover's numbers, may go this turn, by one step or by several of its own; a
    /// shorter way is preferred, and among equals one that hits on the way.
    func routes(from point: Int) -> [Route] {
        var found: [Route] = []
        let k = played.count
        func hits(_ steps: [Step]) -> Int { steps.filter(\.hit).count }
        for move in sequences where move.count > k && move.steps[k].from == point && move.steps.starts(with: played) {
            var chain: [Step] = []
            for step in move.steps[k...] {
                if let last = chain.last, step.from != last.to || last.to == Nardy.bearOff {
                    break
                }
                chain.append(step)
                if let index = found.firstIndex(where: { $0.to == step.to }) {
                    let known = found[index].steps
                    if chain.count < known.count || (chain.count == known.count && hits(chain) > hits(known)) {
                        found[index].steps = chain
                    }
                } else {
                    found.append(Route(to: step.to, steps: chain))
                }
            }
        }
        return found
    }

    func playRoute(_ route: Route) {
        for step in route.steps {
            playStep(step)
        }
    }

    /// The checker on `point` goes by the higher die it may use, else the lower.
    func playLargerDie(from point: Int) {
        var best: Step?
        for step in nextSteps() where step.from == point && step.die > (best?.die ?? 0) {
            best = step
        }
        if let best {
            playStep(best)
        }
    }

    /// The place chosen to move from, as `BoardView` counts places, its top checker raised; -1 for none.
    func select(_ place: Int) {
        selected = place
        boardView.lift(side: place >= 0 ? toPlay : -1, place: place)
    }

    /// Why a checker of the player to move may not go now, in words.
    func whyNot(_ point: Int) -> String {
        let mover = moverView
        if game == .short && mover.bar[0] > 0 && point != Nardy.fromBar {
            return text(.enterFirst)
        }
        if game == .long && point == Nardy.head && played.contains(where: { $0.from == Nardy.head }) {
            return text(.headRule)
        }
        return text(.cannotMove)
    }

    /// A turn as players write it, from the mover's side: one checker's steps joined ("24/13", or "24/18*/13" when it
    /// hit on the way), and the same move made twice counted ("13/7(2)").
    func moveText(_ steps: [Step]) -> String {
        func pointName(_ point: Int) -> String {
            if point == Nardy.fromBar {
                return text(.bar)
            }
            if point == Nardy.bearOff {
                return text(.off)
            }
            return String(point + 1)
        }
        var parts: [String] = []
        var i = 0
        while i < steps.count {
            var j = i
            while j + 1 < steps.count && steps[j + 1].from == steps[j].to && steps[j].to != Nardy.bearOff {
                j += 1
            }
            var part = pointName(steps[i].from)
            for k in i...j where k == j || steps[k].hit {
                part += "/" + pointName(steps[k].to) + (steps[k].hit ? "*" : "")
            }
            parts.append(part)
            i = j + 1
        }
        var words: [String] = []
        for (index, part) in parts.enumerated() where !parts[..<index].contains(part) {
            let times = parts.filter { $0 == part }.count
            words.append(times > 1 ? "\(part)(\(times))" : part)
        }
        return words.joined(separator: " ")
    }

    // MARK: - Keeping a game

    /// A game in progress as text: the game, who is to play, the first moves still to make, the dice if thrown, and
    /// the board as White sees it when the turn began. Empty when no game is in progress.
    var savedGame: String {
        if stage == .opening || stage == .over {
            return ""
        }
        let position = rolled ? turnStart : board
        var values = [game.rawValue, toPlay, firstMove[0] ? 1 : 0, firstMove[1] ? 1 : 0, rolled ? 1 : 0, roll.first, roll.second]
        values += (0..<Nardy.points).map { Int(position.points[$0]) }
        values += [Int(position.bar[0]), Int(position.bar[1]), Int(position.off[0]), Int(position.off[1])]
        return values.map(String.init).joined(separator: " ")
    }

    /// Takes up a game kept by `savedGame`; false, and nothing changed, when the text does not hold one of this game.
    func loadGame(_ text: String) -> Bool {
        let words = text.split(separator: " ")
        let values = words.compactMap { Int($0) }
        guard values.count == 35, words.count == 35, values[0] == game.rawValue, (0...1).contains(values[1]), (1...6).contains(values[5]),
              (1...6).contains(values[6]) else { return false }
        var position = Position()
        var count = [0, 0]
        for i in 0..<Nardy.points {
            let n = values[7 + i]
            guard abs(n) <= Nardy.checkers else { return false }
            position.points[i] = Int8(n)
            count[n > 0 ? 0 : 1] += abs(n)
        }
        for side in 0..<2 {
            let bar = values[31 + side]
            let off = values[33 + side]
            guard (0...Nardy.checkers).contains(bar), (0..<Nardy.checkers).contains(off), bar == 0 || game == .short else { return false }
            position.bar[side] = Int8(bar)
            position.off[side] = Int8(off)
            count[side] += bar + off
        }
        guard count == [Nardy.checkers, Nardy.checkers] else { return false }

        board = position
        toPlay = values[1]
        firstMove = [values[2] != 0, values[3] != 0]
        roll = Roll(first: values[5], second: values[6])
        winner = -1
        boardView.reset(board)
        boardView.clearDice()
        turn = 1
        if values[4] != 0 {
            rolled = true
            turnStart = board
            boardView.showDice(side: toPlay, first: roll.first, second: roll.second)
            beginMoves()
        } else {
            startTurn()
        }
        return true
    }
}
