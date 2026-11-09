import AppKit
import Metal
import simd

/// The game: it runs the games, the computer players and the interface, and has the renderer draw them into the view.
/// The interface is drawn immediately: each frame lays out the widgets and hears the pointer at once.
@MainActor
final class GameController {
    enum Mode: Int, CaseIterable {
        case vsComputer, twoPlayers, demo
    }

    /// The players throw a die each to see who starts; then each turn the dice are thrown and fly, and the checkers are
    /// moved: by hand, or by the computer, which thinks and then plays its steps one by one. Then the game is over.
    enum Stage {
        case opening, toRoll, rolling, moving, thinking, playing, over
    }

    enum Gesture {
        case none, press, drag, turnCamera
    }

    /// The widgets that take the pointer while it is held; a selector has two, for its arrows.
    enum Widget {
        static let help = 1
        static let roll = 2
        static let hint = 3
        static let undo = 4
        static let newGame = 5
        static let autoRoll = 6
        static let camera = 7
        static let sound = 8
        static let language = 9
        static let game = 10
        static let mode = 12
        static let level = 14
        static let theme = 16
        /// Past it, the widgets of the help, which work while it is open.
        static let modal = 100
        static let helpClose = 101
    }

    struct Toast {
        var text: String
        var age: Float = 0
    }

    /// A person's turn as it began, with its dice: what taking back a turn returns to.
    struct Snapshot {
        var board: Position
        var toPlay: Int
        var firstMove: [Bool]
        var roll: Roll
        var history: Int
        var turn: Int
    }

    struct HistoryLine {
        var text: String
        /// 0 White's turn, 1 Black's, 2 a note, 3 the end of the game.
        var kind: Int
    }

    /// A way for the checker chosen to reach a place: the steps, one checker's, in order.
    struct Route {
        /// In the mover's numbers: a point or `Nardy.bearOff`.
        var to: Int
        var steps: [Step]
    }

    static let panelWidth: Float = 352
    static let panelMargin: Float = 16
    /// Seconds the computer takes over a move, at least.
    static let minThink: Float = 0.5
    /// Between the computer's steps.
    static let stepPause: Float = 0.45
    /// After the last step, before the turn passes.
    static let turnPause: Float = 0.55
    /// When nothing can be played.
    static let passPause: Float = 1.6
    /// Points the pointer travels before a press becomes a drag.
    static let dragStart: Float = 6
    static let textColor = RGBA(236, 239, 245)
    static let mutedColor = RGBA(150, 158, 176)
    static let noteColor = RGBA(255, 200, 130)

    // Collaborators.
    weak var view: GameView?
    let renderer: Renderer
    let painter: Painter
    let sound: SoundBank
    /// Told when the language changes, for the menus and the window's title.
    var languageChanged: (@MainActor (Language) -> Void)?

    // The window.
    var width = 0 // of the picture, in pixels
    var height = 0
    var scale: Float = 1 // of the interface: pixels for a point
    var fontScale: Float = 0 // that the fonts were made for
    var dirty = true // something to draw since the last frame
    var cursorHand = false
    let clock = ContinuousClock()
    var lastFrame: ContinuousClock.Instant
    var time: Float = 0

    // The game.
    var settings: Settings
    var language: Language
    /// The judgement of positions, for long and short nardy.
    let nets: [Network]
    /// As White sees it.
    var board = Position()
    var toPlay = 0
    var firstMove = [true, true]
    var roll = Roll()
    var rolled = false
    /// The dice thrown to see who starts.
    var opening = [1, 1]
    var turnStart = Position()
    /// This turn's steps so far, in the mover's numbers.
    var played: [Step] = []
    /// Every legal way to play this turn's roll.
    var sequences: [Move] = []
    /// The places the last turn moved from and to, as `BoardView` counts them.
    var lastMove: [Int] = []
    var score = [0, 0]
    var winner = -1
    var winPoints = 0
    var stage = Stage.opening
    var stageClock: Float = 0
    /// Counts down after the last step of a turn, before it ends.
    var doneClock: Float = -1
    var mode = Mode.vsComputer
    var level = 3
    var themeIndex = 0
    var game = Variant.long
    var autoRoll = true
    var turn = 0
    var random = RandomSource()
    var undoStack: [Snapshot] = []
    var history: [HistoryLine] = []
    var boardView = BoardView()

    // The computer.
    let computer = ComputerWorker()
    var computerMove: Move?
    var computerStep = 0
    var stepClock: Float = 0
    let hintWorker = ComputerWorker()
    var hintWanted = false
    var hint: Move?

    // The view and the pointer.
    var camera = BoardCamera()
    var pointer = Pointer()
    var gesture = Gesture.none
    var pressX: Float = 0
    var pressY: Float = 0
    var dragX: Float = 0
    var dragY: Float = 0
    var pressRight = false
    var pressDouble = false
    var pressPlace = -1
    /// Where the last click chose or let go of a checker, for a double-click.
    var toggledPlace = -1
    /// The place chosen to move from, as `BoardView` counts places.
    var selected = -1
    var hoverPlace = -1

    // The interface.
    var activeWidget = 0
    var panelVisible = true
    var panelSlide: Float = 1
    var helpVisible = false
    var historyScroll: Float = 0
    var followHistory = true
    var bannerFade: Float = 0
    /// Left to show; below zero it stays.
    var bannerTime: Float = 0
    var bannerTitle = ""
    var bannerDetail = ""
    var toasts: [Toast] = []

    init(view: GameView) throws {
        guard let device = view.device else { throw RendererError.noDevice }
        let settings = Settings.load(themeCount: Themes.all.count)
        let renderer = try Renderer(device: device, drawableFormat: view.colorPixelFormat)
        try renderer.setTheme(Themes.all[settings.theme])
        self.renderer = renderer
        nets = try ["long", "short"].map { name in
            guard let url = ResourceBundle.url(forResource: name, withExtension: "net"), let data = try? Data(contentsOf: url),
                  let net = Network(data: data) else { throw GameError.damagedNetwork("\(name).net") }
            return net
        }
        painter = Painter(device: device, framesInFlight: Renderer.framesInFlight)
        sound = SoundBank()
        self.view = view
        self.settings = settings
        language = settings.language
        themeIndex = settings.theme
        level = settings.level
        mode = Mode(rawValue: settings.mode) ?? .vsComputer
        game = Variant(rawValue: settings.game) ?? .long
        autoRoll = settings.autoRoll
        score = settings.score
        panelVisible = settings.panel
        panelSlide = settings.panel ? 1 : 0
        lastFrame = clock.now

        sound.isEnabled = settings.sound
        camera.setMode(CameraMode(rawValue: settings.camera) ?? .overview)
        if loadGame(settings.match) {
            // The history of the game, as far as it was kept.
            for line in settings.history.split(separator: "|") {
                if line.count > 1, let kind = line.first?.wholeNumberValue, (0...3).contains(kind) {
                    history.append(HistoryLine(text: String(line.dropFirst()), kind: kind))
                }
            }
        } else {
            newGame()
        }
    }

    var theme: Theme { Themes.all[themeIndex] }

    var accent: RGBA { RGBA(linear: theme.accent) }

    var isFullScreen: Bool { view?.window?.styleMask.contains(.fullScreen) ?? false }

    func text(_ id: Str) -> String { id.text(language) }

    func text(_ id: Str, _ values: CustomStringConvertible...) -> String {
        var result = ""
        var rest = Substring(id.text(language))
        var next = values.makeIterator()
        while let place = rest.range(of: "{}") {
            result += rest[..<place.lowerBound]
            result += next.next()?.description ?? ""
            rest = rest[place.upperBound...]
        }
        return result + rest
    }

    /// Stops the computer and keeps the game, when the program ends.
    func shutDown() {
        stopComputer()
        save()
    }

    // MARK: - Frames

    /// Something changed: a frame is drawn soon, and the animation clock does not count the time the view rested.
    func requestFrame() {
        dirty = true
        guard let view, view.isPaused else { return }
        lastFrame = clock.now
        view.isPaused = false
    }

    /// Updates the game, lays out the interface and draws a frame; the view rests afterwards while nothing moves.
    func frame() {
        guard let view else { return }
        // Nothing moves while the window cannot be seen: the game goes on from there when it shows again.
        if let window = view.window, !window.occlusionState.contains(.visible) {
            rest(true)
            return
        }
        let now = clock.now
        let elapsed = lastFrame.duration(to: now).components
        let seconds = min(Float(Double(elapsed.seconds) + Double(elapsed.attoseconds) * 1e-18), 0.1)
        lastFrame = now
        time += seconds
        dirty = false

        updateSize()
        guard width > 0, height > 0 else {
            rest(true) // until the view has a size again
            return
        }
        if scale != fontScale {
            buildFonts()
        }
        update(seconds)

        let scene = buildScene()
        cursorHand = false
        painter.begin(width: width, height: height)
        drawInterface()
        handleBoardPointer()
        if let drawable = view.currentDrawable {
            renderer.render(scene, to: drawable) { encoder, frameIndex in
                painter.encode(encoder, frameIndex: frameIndex)
            }
        }

        // The widgets are drawn as they were before they heard the click: what it changed shows in the next frame.
        if pointer.leftPressed || pointer.leftReleased || pointer.rightPressed || pointer.rightReleased {
            dirty = true
        }
        pointer.leftPressed = false
        pointer.leftReleased = false
        pointer.rightPressed = false
        pointer.rightReleased = false
        pointer.doubleClick = false
        pointer.zoom = 0
        pointer.scroll = 0
        pointer.consumed = false
        view.setCursor(hand: cursorHand)
        rest(!(dirty || needsAnimation))
    }

    /// Stops the frames, or lets them run, touching the view only when that changes.
    private func rest(_ resting: Bool) {
        if let view, view.isPaused != resting {
            view.isPaused = resting
        }
    }

    private func updateSize() {
        guard let view else { return }
        width = Int(view.drawableSize.width)
        height = Int(view.drawableSize.height)
        let points = Float(view.bounds.width)
        scale = min(max(points > 0 ? Float(width) / points : 1, 0.5), 4)
    }

    private func buildFonts() {
        do {
            let fonts = try FontId.allCases.map { id in
                try FontAtlas(device: renderer.device, queue: renderer.queue, pixelHeight: id.size * scale, semibold: id.isSemibold)
            }
            painter.setFonts(fonts)
            fontScale = scale
        } catch {
            FileHandle.standardError.write(Data("3D Nardy: \(error)\n".utf8))
        }
    }

    private func update(_ seconds: Float) {
        let slideTarget: Float = panelVisible ? 1 : 0
        panelSlide += (slideTarget - panelSlide) * (1 - exp(-seconds * 12))
        if abs(slideTarget - panelSlide) < 0.001 {
            panelSlide = slideTarget
        }
        camera.setSpace(freeArea.width / max(1, Float(width)))

        stageClock += seconds
        switch stage {
        case .opening:
            if !boardView.diceRolling && stageClock > 1.6 {
                finishOpening()
            }
        case .toRoll:
            if (!isHuman(toPlay) && stageClock > 0.45) || (isHuman(toPlay) && autoRoll && stageClock > 0.3) {
                rollDice()
            }
        case .rolling:
            if !boardView.diceRolling {
                beginMoves()
            }
        case .moving:
            if doneClock > 0 {
                doneClock -= seconds
                if doneClock <= 0 {
                    endTurn()
                }
            }
        case .thinking, .playing:
            updateComputer(seconds)
        case .over:
            if mode == .demo && stageClock > 6 {
                newGame()
            }
        }
        updateHint()
        boardView.update(seconds)
        playSounds()
        camera.update(seconds)

        for index in toasts.indices {
            toasts[index].age += seconds
        }
        toasts.removeAll { $0.age > 2.8 }
        var bannerTarget: Float = 0
        if bannerTime < 0 {
            bannerTarget = 1
        } else if bannerTime > 0 {
            bannerTarget = 1
            bannerTime = max(0, bannerTime - seconds)
        }
        bannerFade += (bannerTarget - bannerFade) * (1 - exp(-seconds * 7))
        if abs(bannerTarget - bannerFade) < 0.002 {
            bannerFade = bannerTarget
        }
    }

    /// What the checkers and the dice made heard this frame, each a little different in pitch.
    private func playSounds() {
        let heard = boardView.takeSounds()
        func vary() -> Float { Float(random.uniform(0.93, 1.07)) }
        for _ in 0..<min(heard.landings, 3) {
            sound.play(.checker, volume: 0.8, pitch: vary())
        }
        for _ in 0..<min(heard.hits, 2) {
            sound.play(.hit, volume: 0.9, pitch: vary())
        }
        for _ in 0..<min(heard.trays, 3) {
            sound.play(.tray, volume: 0.8, pan: 0.4, pitch: vary())
        }
        for volume in heard.dice {
            sound.play(.die, volume: volume, pitch: vary())
        }
    }

    var needsAnimation: Bool {
        let waiting = stage == .opening || stage == .rolling || stage == .thinking || stage == .playing
            || (stage == .toRoll && (!isHuman(toPlay) || autoRoll)) || (stage == .moving && doneClock > 0) || (stage == .over && mode == .demo)
        // The places a checker may go pulse, and so does the hint.
        let pulsing = isHumanToMove && (selected >= 0 || hint != nil)
        return waiting || pulsing || hintWanted || camera.isMoving || boardView.isAnimating || !toasts.isEmpty || bannerTime > 0
            || (bannerFade > 0.001 && bannerFade < 0.999) || abs(panelSlide - (panelVisible ? 1 : 0)) > 0.001
    }

    // MARK: - The scene

    private func buildScene() -> RenderScene {
        var scene = RenderScene()
        let aspect = Float(width) / max(1, Float(height))
        scene.view = camera.view
        scene.projection = camera.projection(aspect: aspect)
        scene.eye = camera.eye
        scene.time = time

        func mark(_ place: Int, _ component: Int, _ value: Float) {
            if place >= 0 && place < Nardy.points {
                scene.points[place][component] = max(scene.points[place][component], value)
            }
        }
        // The last turn's steps, until the next player moves.
        if played.isEmpty || stage == .over {
            for place in lastMove {
                mark(place, 2, 1)
            }
        }

        var glow = [Float](repeating: 0, count: BoardView.places)
        var glowSide = -1
        if isHumanToMove && doneClock <= 0 {
            glowSide = toPlay
            for step in nextSteps() {
                let place = toPlace(step.from)
                glow[place] = max(glow[place], selected < 0 ? 0.32 : 0.16)
                if selected < 0 {
                    mark(place, 1, 1)
                }
            }
            if hoverPlace >= 0 && glow[hoverPlace] > 0 {
                glow[hoverPlace] = 0.7
            }
            if selected >= 0 {
                for route in routes(from: fromPlace(selected)) {
                    let place = toPlace(route.to)
                    let strength: Float = place == hoverPlace ? 1.6 : 1.0
                    if place == BoardView.offPlace {
                        scene.trays[toPlay == 0 ? 0 : 1] = strength
                    } else {
                        mark(place, 0, strength)
                    }
                }
            }
        }
        if let hint, isHumanToMove {
            for step in hint.steps {
                mark(toPlace(step.from), 3, 1)
                if step.to == Nardy.bearOff {
                    scene.trays.z = toPlay == 0 ? 1 : -1
                } else {
                    mark(toPlace(step.to), 3, 1)
                }
            }
        }

        scene.pieces = boardView.pieces(glow: glow, glowSide: glowSide)
        scene.panels = frostedPanels
        return scene
    }
}
