import Foundation

/// The game's course: the opening throw, the turns of the players and the computer, taking back, the end of a game,
/// and the choices that change it.
extension GameController {
    var isHumanToMove: Bool { stage == .moving && isHuman(toPlay) }

    /// The network for the game being played.
    var net: Network { nets[game.rawValue] }

    func isHuman(_ side: Int) -> Bool {
        switch mode {
        case .vsComputer: side == 0
        case .twoPlayers: true
        case .demo: false
        }
    }

    /// The board as the player to move sees it.
    var moverView: Position { toPlay == 0 ? board : Nardy.flip(board, game) }

    func setFromMover(_ mover: Position) {
        board = toPlay == 0 ? mover : Nardy.flip(mover, game)
    }

    /// A place in the mover's numbers (a point, `Nardy.fromBar` or `Nardy.bearOff`) as `BoardView` counts places.
    func toPlace(_ point: Int) -> Int {
        if point == Nardy.fromBar {
            return BoardView.barPlace
        }
        if point == Nardy.bearOff {
            return BoardView.offPlace
        }
        if toPlay == 0 {
            return point
        }
        // Black counts the points from the other end: short nardy the opposite way round, long nardy from the far side.
        return game == .short ? Nardy.points - 1 - point : (point + 12) % Nardy.points
    }

    /// A place as `BoardView` counts places, in the mover's numbers; -100 for none.
    func fromPlace(_ place: Int) -> Int {
        if place == BoardView.barPlace {
            return Nardy.fromBar
        }
        if place == BoardView.offPlace {
            return Nardy.bearOff
        }
        if place < 0 {
            return -100
        }
        return toPlace(place) // the same reckoning, both ways
    }

    // MARK: - A game

    func newGame() {
        stopComputer()
        board = Nardy.start(game)
        firstMove = [true, true]
        rolled = false
        played.removeAll()
        sequences.removeAll()
        lastMove.removeAll()
        winner = -1
        winPoints = 0
        turn = 0
        doneClock = -1
        undoStack.removeAll()
        history.removeAll()
        historyScroll = 0
        followHistory = true
        bannerTime = 0
        select(-1)
        boardView.reset(board)
        boardView.clearDice()
        sound.play(.setup)
        throwOpening()
        save()
    }

    func throwOpening() {
        opening = [1 + random.below(6), 1 + random.below(6)]
        boardView.throwOpening(white: opening[0], black: opening[1], random: &random)
        sound.play(.rattle)
        stage = .opening
        stageClock = 0
    }

    /// The dice of the opening have settled: the higher starts, or both throw again.
    func finishOpening() {
        if opening[0] == opening[1] {
            showToast(text(.openingTie, opening[0], opening[1]))
            throwOpening()
            return
        }
        toPlay = opening[0] > opening[1] ? 0 : 1
        let starts = pick(toPlay, .startsYou, .startsComputer, .startsWhite, .startsBlack)
        showToast(starts)
        addHistory("\(starts) (\(opening[0]):\(opening[1]))", kind: 2)
        if game == .short {
            // In short nardy the opening dice are the first roll.
            turn += 1
            roll = Roll(first: opening[0], second: opening[1])
            rolled = true
            turnStart = board
            beginMoves()
        } else {
            startTurn()
        }
        save()
    }

    func startTurn() {
        turn += 1
        stage = .toRoll
        stageClock = 0
        rolled = false
        played.removeAll()
        sequences.removeAll()
        doneClock = -1
        hint = nil
        hintWanted = false
        select(-1)
    }

    func rollDice() {
        guard stage == .toRoll else { return }
        roll = Roll(first: 1 + random.below(6), second: 1 + random.below(6))
        rolled = true
        turnStart = board
        boardView.throwDice(side: toPlay, first: roll.first, second: roll.second, random: &random)
        sound.play(.rattle)
        stage = .rolling
        stageClock = 0
    }

    /// The dice lie still: every way to play them is found, and the player to move takes over.
    func beginMoves() {
        turnStart = board
        played.removeAll()
        sequences = Nardy.legalSequences(moverView, game, roll, firstMove: firstMove[toPlay])
        doneClock = -1
        hint = nil
        hintWanted = false
        hintWorker.cancel()
        select(-1)
        boardView.useDice(0, doubles: roll.isDouble, firstUsed: 0)
        stageClock = 0
        if sequences.isEmpty {
            // Nothing can be played: the turn passes.
            stage = .moving
            doneClock = Self.passPause
            showToast(text(.noMovesToast))
            sound.play(.noMove)
            return
        }
        if isHuman(toPlay) {
            if let last = undoStack.last, last.turn >= turn {
                undoStack.removeLast()
            }
            undoStack.append(Snapshot(board: board, toPlay: toPlay, firstMove: firstMove, roll: roll, history: history.count, turn: turn))
            if undoStack.count > 300 {
                undoStack.removeFirst()
            }
            stage = .moving
            return
        }
        stage = .thinking
        computerMove = nil
        computer.start(net: net, position: moverView, variant: game, roll: roll, firstMove: firstMove[toPlay], opponentFirst: firstMove[1 - toPlay],
                       level: level, seed: random.next())
    }

    func playStep(_ step: Step) {
        let after = Nardy.apply(moverView, step)
        boardView.move(side: toPlay, from: toPlace(step.from), to: toPlace(step.to))
        setFromMover(after)
        if played.isEmpty {
            lastMove.removeAll()
        }
        played.append(step)
        boardView.useDice(played.count, doubles: roll.isDouble, firstUsed: played[0].die == roll.first ? 0 : 1)
        hint = nil
        hintWanted = false
        hintWorker.cancel()
        select(-1)
        if isHuman(toPlay) && nextSteps().isEmpty {
            doneClock = Self.turnPause
        }
    }

    func takeBackStep() {
        guard isHumanToMove, let step = played.popLast() else { return }
        var mover = toPlay == 0 ? turnStart : Nardy.flip(turnStart, game)
        for earlier in played {
            mover = Nardy.apply(mover, earlier)
        }
        setFromMover(mover)
        // The checker flies back, and one it knocked off returns from the bar.
        boardView.move(side: toPlay, from: toPlace(step.to), to: toPlace(step.from))
        if step.hit {
            boardView.move(side: 1 - toPlay, from: BoardView.barPlace, to: toPlace(step.to))
        }
        boardView.useDice(played.count, doubles: roll.isDouble, firstUsed: played.first.map { $0.die == roll.first ? 0 : 1 } ?? 0)
        doneClock = -1
        select(-1)
    }

    func takeBackTurn() {
        while isHumanToMove && !played.isEmpty {
            takeBackStep()
        }
    }

    /// Takes back this turn's steps, or else goes back to the start of the last turn a person played, with its dice.
    func undo() {
        if mode == .demo {
            return
        }
        if isHumanToMove && !played.isEmpty {
            takeBackTurn()
            return
        }
        while let last = undoStack.last, last.turn >= turn, stage != .over {
            undoStack.removeLast()
        }
        guard let snapshot = undoStack.last else {
            showToast(text(.nothingToUndo))
            return
        }
        stopComputer()
        if stage == .over && winner >= 0 {
            score[winner] -= winPoints
            bannerTime = 0
        }
        winner = -1
        board = snapshot.board
        toPlay = snapshot.toPlay
        firstMove = snapshot.firstMove
        roll = snapshot.roll
        turn = snapshot.turn
        if history.count > snapshot.history {
            history.removeSubrange(snapshot.history...)
        }
        lastMove.removeAll()
        rolled = true
        boardView.reset(board)
        boardView.showDice(side: toPlay, first: roll.first, second: roll.second)
        beginMoves()
        save()
    }

    func endTurn() {
        doneClock = -1
        let side = toPlay
        let high = max(roll.first, roll.second)
        let low = min(roll.first, roll.second)
        let moves = played.isEmpty ? text(.noMoves) : moveText(played)
        addHistory("\(playerName(side)) \(high)-\(low): \(moves)", kind: side)
        // Where each checker moved from and to: a checker going on with the next step marks only its start and its end.
        lastMove.removeAll()
        for i in played.indices {
            if i == 0 || played[i].from != played[i - 1].to {
                lastMove.append(toPlace(played[i].from))
            }
            if i + 1 == played.count || played[i + 1].from != played[i].to {
                lastMove.append(toPlace(played[i].to))
            }
        }
        firstMove[side] = false
        if Int(board.off[side]) == Nardy.checkers {
            finishGame()
            return
        }
        toPlay = 1 - side
        startTurn()
        save()
    }

    func finishGame() {
        let side = toPlay
        winner = side
        winPoints = Nardy.winPoints(moverView, game)
        score[side] += winPoints
        stage = .over
        stageClock = 0
        let title = pick(side, .winYou, .winComputer, .winWhite, .winBlack)
        let points = text(winPoints >= 3 ? .pointsKoks : winPoints == 2 ? .pointsMars : .pointsOne)
        showBanner(title, "\(points)  ·  \(text(.score, score[0], score[1]))", seconds: -1)
        addHistory("\(title) — \(points)", kind: 3)
        sound.play(.win)
        save()
    }

    // MARK: - The computer

    func stopComputer() {
        computer.cancel()
        computerMove = nil
        hintWorker.cancel()
        hintWanted = false
    }

    /// The computer thinks for a while at least, then plays its steps one by one.
    func updateComputer(_ seconds: Float) {
        if stage == .thinking {
            if computerMove == nil {
                computerMove = computer.take()
            }
            if computerMove != nil && stageClock >= Self.minThink {
                stage = .playing
                stageClock = 0
                computerStep = 0
                stepClock = 0.1
            }
            return
        }
        stepClock -= seconds
        guard stepClock <= 0, let move = computerMove else { return }
        if computerStep < move.count {
            playStep(move.steps[computerStep])
            computerStep += 1
            stepClock = computerStep < move.count ? Self.stepPause : Self.turnPause + 0.2
        } else {
            endTurn()
        }
    }

    /// The computer's advice for the whole roll, at its best: any steps already played are taken back first. Asked
    /// again, the move is played.
    func requestHint() {
        guard isHumanToMove, !sequences.isEmpty, doneClock <= 0 else { return }
        if let hint {
            for step in hint.steps {
                playStep(step)
            }
            return
        }
        takeBackTurn()
        hintWanted = true
        hintWorker.start(net: net, position: moverView, variant: game, roll: roll, firstMove: firstMove[toPlay], opponentFirst: firstMove[1 - toPlay],
                         level: 5, seed: random.next())
    }

    func updateHint() {
        guard hintWanted, let move = hintWorker.take() else { return }
        hintWanted = false
        guard isHumanToMove, played.isEmpty else { return }
        hint = move
        showToast(text(.hintText, moveText(move.steps)))
    }

    // MARK: - The choices

    func setGame(_ index: Int) {
        game = Variant(rawValue: (index + 2) % 2) ?? .long
        score = [0, 0]
        newGame()
    }

    func setMode(_ index: Int) {
        let newMode = Mode(rawValue: (index + Mode.allCases.count) % Mode.allCases.count) ?? .vsComputer
        if newMode == mode {
            return
        }
        let wasHuman = isHuman(toPlay)
        mode = newMode
        score = [0, 0]
        // The player to move may have changed hands: their turn starts again for the new player.
        if wasHuman != isHuman(toPlay) && (stage == .moving || stage == .thinking || stage == .playing) && doneClock <= 0 {
            stopComputer()
            board = turnStart
            boardView.reset(board)
            beginMoves()
        }
        save()
    }

    func setLevel(_ value: Int) {
        level = min(max(value, 1), 5)
        save()
    }

    func setTheme(_ index: Int) {
        themeIndex = (index + Themes.all.count) % Themes.all.count
        do {
            try renderer.setTheme(theme)
        } catch {
            FileHandle.standardError.write(Data("3D Nardy: \(error)\n".utf8))
        }
        save()
    }

    func setCamera(_ index: Int) {
        let count = CameraMode.allCases.count
        camera.setMode(CameraMode(rawValue: (index + count) % count) ?? .overview)
        save()
    }

    func setAutoRoll(_ on: Bool) {
        autoRoll = on
        stageClock = 0
        save()
    }

    func toggleSound() {
        sound.isEnabled.toggle()
        save()
    }

    func toggleLanguage() {
        language = language.other
        languageChanged?(language)
        save()
    }

    func togglePanel() {
        panelVisible.toggle()
        save()
    }

    func toggleFullScreen() {
        view?.window?.toggleFullScreen(nil)
    }

    func save() {
        settings.theme = themeIndex
        settings.level = level
        settings.mode = mode.rawValue
        settings.game = game.rawValue
        settings.camera = camera.mode.rawValue
        settings.autoRoll = autoRoll
        settings.score = score
        settings.sound = sound.isEnabled
        settings.panel = panelVisible
        settings.language = language
        settings.match = savedGame
        settings.history = settings.match.isEmpty ? "" : history.suffix(80).map { "\($0.kind)\($0.text)" }.joined(separator: "|")
        settings.save()
    }

    func addHistory(_ text: String, kind: Int) {
        history.append(HistoryLine(text: text, kind: kind))
        followHistory = true
    }
}
