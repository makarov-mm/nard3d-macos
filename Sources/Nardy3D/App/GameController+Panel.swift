import AppKit
import simd

/// The panel at the right: the status, the players, the buttons of the turn, the moves so far and the choices.
extension GameController {
    var panelRect: ScreenRect {
        let width = Self.panelWidth * scale
        let margin = Self.panelMargin * scale
        return ScreenRect(x: Float(self.width) - (width + margin) * panelSlide, y: margin, width: width, height: Float(height) - 2 * margin)
    }

    /// The window left of the panel.
    var freeArea: ScreenRect {
        ScreenRect(x: 0, y: 0, width: min(panelRect.x, Float(width)), height: Float(height))
    }

    /// The rectangles of the interface behind which the scene is blurred.
    var frostedPanels: [FrostedPanel] {
        var panels: [FrostedPanel] = []
        if panelSlide > 0.001 {
            panels.append(FrostedPanel(rect: panelRect, radius: 18 * scale, opacity: 1))
        }
        if bannerFade > 0.001 {
            panels.append(FrostedPanel(rect: bannerCard, radius: 18 * scale, opacity: bannerFade))
        }
        if helpVisible {
            panels.append(FrostedPanel(rect: helpCard, radius: 20 * scale, opacity: 1))
        }
        return panels
    }

    func drawInterface() {
        drawPanel()
        drawBanner()
        drawToasts()
        if helpVisible {
            drawHelp()
        }
    }

    // MARK: - Widgets

    /// A button; true when it is clicked.
    @discardableResult
    func button(_ id: Int, _ rect: ScreenRect, _ label: String, enabled: Bool = true, accented: Bool = false) -> Bool {
        let interactive = enabled && (!helpVisible || id > Widget.modal)
        let hover = interactive && rect.contains(pointer.x, pointer.y) && gesture == .none
        if hover {
            cursorHand = true
        }
        if hover && pointer.leftPressed {
            activeWidget = id
            pointer.consumed = true
        }
        var clicked = false
        if pointer.leftReleased && activeWidget == id {
            clicked = hover
            activeWidget = 0
            pointer.consumed = true
        }
        let pressed = hover && activeWidget == id && pointer.leftDown
        var fill = !enabled ? RGBA(255, 255, 255, 7) : pressed ? RGBA(255, 255, 255, 52) : hover ? RGBA(255, 255, 255, 34) : RGBA(255, 255, 255, 17)
        if accented && enabled {
            fill = fill.mixed(with: RGBA(linear: theme.accent, alpha: Float(fill.a) / 255 * 2.2), 0.6)
        }
        painter.fill(rect, radius: 9 * scale, color: fill)
        painter.textCentered(.body, in: rect, label, color: enabled ? Self.textColor : Self.textColor.faded(0.35))
        if clicked {
            sound.play(.click)
        }
        return clicked
    }

    /// A label with a value stepped by two arrows; -1 or 1 when one is clicked, else 0.
    private func selector(_ id: Int, _ rect: ScreenRect, _ label: String, _ value: String) -> Int {
        painter.text(.body, x: rect.x, y: rect.y + (rect.height - painter.lineHeight(.body)) / 2, label, color: Self.mutedColor)
        let arrow = rect.height
        let right = ScreenRect(x: rect.right - arrow, y: rect.y, width: arrow, height: rect.height)
        let left = ScreenRect(x: rect.x + rect.width * 0.36, y: rect.y, width: arrow, height: rect.height)
        painter.fill(ScreenRect(x: left.right + 2 * scale, y: rect.y, width: right.x - left.right - 4 * scale, height: rect.height), radius: 9 * scale,
                     color: RGBA(255, 255, 255, 9))
        painter.textCentered(.body, in: ScreenRect(x: left.right, y: rect.y, width: right.x - left.right, height: rect.height), value,
                             color: Self.textColor)
        var change = 0
        if button(id, left, "") {
            change = -1
        }
        if button(id + 1, right, "") {
            change = 1
        }
        let size = 5 * scale
        painter.arrow(x: left.x + left.width / 2, y: left.y + left.height / 2, halfWidth: size * 0.8, halfHeight: size, direction: -1,
                      color: Self.textColor)
        painter.arrow(x: right.x + right.width / 2, y: right.y + right.height / 2, halfWidth: size * 0.8, halfHeight: size, direction: 1,
                      color: Self.textColor)
        return change
    }

    /// A checker seen from above, in its side's colors from the theme.
    private func drawChecker(x: Float, y: Float, radius: Float, side: Int) {
        let linear = theme.checkers[side].color
        // Brightened toward what the lit board shows.
        let color = RGBA(linear: linear * 1.25 + SIMD3(repeating: 0.02))
        let edge = linear.x + linear.y + linear.z > 0.6 ? RGBA(0, 0, 0) : RGBA(255, 255, 255)
        painter.disc(x: x, y: y + radius * 0.14, radius: radius * 1.06, color: RGBA(0, 0, 0, 80))
        painter.disc(x: x, y: y, radius: radius, color: color.mixed(with: edge, 0.18))
        painter.disc(x: x, y: y, radius: radius * 0.84, color: color)
        painter.disc(x: x, y: y, radius: radius * 0.5, color: color.mixed(with: edge, 0.1))
        painter.disc(x: x, y: y, radius: radius * 0.42, color: color)
    }

    /// A die's face with its pips, darkened once played.
    private func drawDie(x: Float, y: Float, size: Float, value: Int, dim: Float) {
        let face = ScreenRect(x: x - size / 2, y: y - size / 2, width: size, height: size)
        painter.shadow(face, blur: size * 0.15, color: RGBA(0, 0, 0, Int(70 * (1 - dim * 0.6))))
        painter.fill(face, radius: size * 0.2, color: RGBA(240, 236, 226).mixed(with: RGBA(90, 92, 100), dim * 0.75))
        // The places of the pips on a grid of three by three, and which of them each number uses.
        let spots: [SIMD2<Float>] = [SIMD2(-1, -1), SIMD2(0, -1), SIMD2(1, -1), SIMD2(-1, 0), SIMD2(0, 0), SIMD2(1, 0), SIMD2(-1, 1), SIMD2(0, 1),
                                     SIMD2(1, 1)]
        let layouts = [[4], [0, 8], [0, 4, 8], [0, 2, 6, 8], [0, 2, 4, 6, 8], [0, 2, 3, 5, 6, 8]]
        let pip = RGBA(24, 22, 22).mixed(with: RGBA(60, 62, 70), dim)
        for index in layouts[min(max(value, 1), 6) - 1] {
            let spot = spots[index]
            painter.disc(x: x + spot.x * size * 0.27, y: y + spot.y * size * 0.27, radius: size * 0.095, color: pip)
        }
    }

    // MARK: - The panel

    private func drawPanel() {
        guard panelSlide > 0.001 else { return }
        let panel = panelRect
        if panel.contains(pointer.x, pointer.y) && (pointer.leftPressed || pointer.rightPressed) && gesture == .none {
            pointer.consumed = true
        }
        painter.shadow(panel, blur: 22 * scale, color: RGBA(0, 0, 0, 70))
        painter.fill(panel, radius: 18 * scale, color: RGBA(16, 18, 26, 120))
        painter.outline(panel, radius: 18 * scale, color: RGBA(255, 255, 255, 24))

        // In a low window everything is packed closer, and the footer goes.
        let compact = panel.height < 820 * scale
        let pad = (compact ? 16 : 20) * scale
        let x = panel.x + pad
        let width = panel.width - 2 * pad
        var y = panel.y + pad

        painter.text(.heading, x: x, y: y, text(.title), color: Self.textColor)
        if button(Widget.help, ScreenRect(x: panel.right - pad - 30 * scale, y: y - 2 * scale, width: 30 * scale, height: 30 * scale), "?") {
            helpVisible.toggle()
        }
        y += (compact ? 38 : 44) * scale

        let statusHeight = (compact ? 54 : 62) * scale
        drawStatus(ScreenRect(x: x, y: y, width: width, height: statusHeight))
        y += statusHeight + (compact ? 6 : 10) * scale

        let playersHeight = 92 * scale
        drawPlayers(ScreenRect(x: x + 4 * scale, y: y, width: width - 8 * scale, height: playersHeight))
        y += playersHeight + (compact ? 6 : 10) * scale

        // The buttons of the turn.
        let rowHeight = (compact ? 29 : 34) * scale
        let gap = (compact ? 5 : 8) * scale
        let half = (width - gap) / 2
        let buttonHeight = (compact ? 31 : 38) * scale
        let canRoll = stage == .toRoll && isHuman(toPlay)
        if button(Widget.roll, ScreenRect(x: x, y: y, width: half, height: buttonHeight), text(.roll), enabled: canRoll, accented: canRoll) {
            rollDice()
        }
        let canHint = isHumanToMove && !sequences.isEmpty && doneClock <= 0 && !hintWanted
        if button(Widget.hint, ScreenRect(x: x + half + gap, y: y, width: half, height: buttonHeight), text(.hint), enabled: canHint,
                  accented: hint != nil && canHint) {
            requestHint()
        }
        y += buttonHeight + gap
        let earlier = undoStack.contains { $0.turn < turn || stage == .over }
        let canUndo = mode != .demo && ((isHumanToMove && !played.isEmpty) || earlier)
        if button(Widget.undo, ScreenRect(x: x, y: y, width: half, height: buttonHeight), text(.undo), enabled: canUndo) {
            undo()
        }
        if button(Widget.newGame, ScreenRect(x: x + half + gap, y: y, width: half, height: buttonHeight), text(.newGame), accented: stage == .over) {
            newGame()
        }
        y += buttonHeight + (compact ? 8 : 12) * scale

        // From the bottom up: the footer, the switches and the settings; the moves take the space between.
        var bottom = panel.bottom - pad
        if !compact {
            let footerHeight = painter.lineHeight(.body)
            painter.textCentered(.body, in: ScreenRect(x: x, y: bottom - footerHeight, width: width, height: footerHeight), text(.footer),
                                 color: Self.mutedColor.faded(0.8))
            bottom -= footerHeight + 14 * scale
        }

        bottom -= rowHeight
        if button(Widget.sound, ScreenRect(x: x, y: bottom, width: half, height: rowHeight), text(.sound), accented: sound.isEnabled) {
            toggleSound()
        }
        if button(Widget.language, ScreenRect(x: x + half + gap, y: bottom, width: half, height: rowHeight), text(.languageName)) {
            toggleLanguage()
        }
        bottom -= gap + rowHeight
        if button(Widget.autoRoll, ScreenRect(x: x, y: bottom, width: half, height: rowHeight), text(.autoRoll), accented: autoRoll) {
            setAutoRoll(!autoRoll)
        }
        let viewName = "\(text(.camera)): \(text(camera.mode == .overview ? .cameraOverview : .cameraTop))"
        if button(Widget.camera, ScreenRect(x: x + half + gap, y: bottom, width: half, height: rowHeight), viewName) {
            setCamera(camera.mode.rawValue + 1)
        }
        bottom -= gap

        let modes: [Str] = [.modeComputer, .modeTwoPlayers, .modeDemo]
        let choices: [(id: Int, label: Str, value: String)] = [
            (Widget.theme, .theme, theme.name(language)),
            (Widget.level, .level, "\(level) · \(text(Str.levelName(level)))"),
            (Widget.mode, .mode, text(modes[mode.rawValue])),
            (Widget.game, .game, text(game == .long ? .gameLong : .gameShort)),
        ]
        for choice in choices {
            bottom -= rowHeight
            let change = selector(choice.id, ScreenRect(x: x, y: bottom, width: width, height: rowHeight), text(choice.label), choice.value)
            if change != 0 {
                switch choice.id {
                case Widget.theme: setTheme(themeIndex + change)
                case Widget.level: setLevel(level + change)
                case Widget.mode: setMode(mode.rawValue + change)
                default: setGame(game.rawValue + change)
                }
            }
            bottom -= (compact ? 3 : 6) * scale
        }
        bottom -= (compact ? 6 : 10) * scale

        // The moves so far, where there is room for them.
        let labelHeight = painter.lineHeight(.body) + 6 * scale
        if bottom - y - labelHeight > 36 * scale {
            painter.text(.body, x: x, y: y, text(.history), color: Self.mutedColor)
            drawHistory(ScreenRect(x: x, y: y + labelHeight, width: width, height: bottom - y - labelHeight))
        }
    }

    /// Whose turn it is and what happens in it; the dice of the turn on the right, the played ones darkened.
    private func drawStatus(_ area: ScreenRect) {
        painter.fill(area, radius: 12 * scale, color: RGBA(255, 255, 255, 14))

        let side = stage == .over ? winner : toPlay
        if stage != .opening && side >= 0 {
            drawChecker(x: area.x + 24 * scale, y: area.y + area.height / 2, radius: 11 * scale, side: side)
        }

        var right = area.right - 10 * scale
        let showDice = rolled && stage != .rolling && stage != .toRoll && stage != .over
        if showDice {
            let dice = roll.dice
            let size = (dice.count > 2 ? 17 : 22) * scale
            let gap = 5 * scale
            var used = [Bool](repeating: false, count: dice.count)
            for step in played {
                if let index = dice.indices.first(where: { !used[$0] && dice[$0] == step.die }) {
                    used[index] = true
                }
            }
            for index in dice.indices.reversed() {
                drawDie(x: right - size / 2, y: area.y + area.height / 2, size: size, value: dice[index], dim: used[index] ? 1 : 0)
                right -= size + gap
            }
            right -= 4 * scale
        }
        if stage == .thinking {
            painter.spinner(x: right - 10 * scale, y: area.y + area.height / 2, radius: 8 * scale, thickness: 2.2 * scale, angle: time * 5,
                            color: accent)
            right -= 26 * scale
        }

        let textX = area.x + (stage == .opening ? 16 : 46) * scale
        let lineHeight = painter.lineHeight(.heading)
        func fit(_ text: String, _ font: FontId) -> String {
            let room = right - textX
            if painter.measure(font, text) <= room {
                return text
            }
            // Cut to fit, at a whole character, with an ellipsis.
            var cut = text
            while cut.count > 1 && painter.measure(font, cut + "…") > room {
                cut.removeLast()
            }
            return cut + "…"
        }
        painter.text(.heading, x: textX, y: area.y + area.height / 2 - lineHeight + 3 * scale, fit(statusTitle, .heading),
                     color: stage == .over ? accent : Self.textColor)
        painter.text(.body, x: textX, y: area.y + area.height / 2 + 2 * scale, fit(statusDetail, .body), color: Self.mutedColor)
    }

    /// The players: who is to move, their pips and checkers borne off, and the points they have won.
    private func drawPlayers(_ area: ScreenRect) {
        let rowHeight = 46 * scale
        for side in 0..<2 {
            let y = area.y + Float(side) * rowHeight
            let toMove = stage != .over && stage != .opening && toPlay == side
            let isWinner = stage == .over && winner == side
            if toMove || isWinner {
                painter.fill(ScreenRect(x: area.x - 6 * scale, y: y + 2 * scale, width: area.width + 12 * scale, height: rowHeight - 4 * scale),
                             radius: 9 * scale, color: accent.faded(isWinner ? 0.3 : 0.16))
            }
            drawChecker(x: area.x + 10 * scale, y: y + rowHeight / 2, radius: 9 * scale, side: side)
            var name = playerName(side)
            if !isHuman(side) {
                name += "  ·  \(text(Str.levelName(level)))"
            }
            let textX = area.x + 28 * scale
            let bodyHeight = painter.lineHeight(.body)
            painter.text(.body, x: textX, y: y + rowHeight / 2 - bodyHeight + 1 * scale, name,
                         color: toMove || isWinner ? Self.textColor : Self.textColor.faded(0.8))
            let pips = Nardy.pips(board, side: side, game)
            painter.text(.body, x: textX, y: y + rowHeight / 2 + 1 * scale, text(.pips, pips, Int(board.off[side])), color: Self.mutedColor)
            let points = String(score[side])
            painter.text(.display, x: area.right - painter.measure(.display, points), y: y + (rowHeight - painter.lineHeight(.display)) / 2, points,
                         color: toMove || isWinner ? Self.textColor : Self.textColor.faded(0.7))
        }
    }

    /// The moves so far, the latest at the bottom; the list scrolls under the pointer and follows the game.
    private func drawHistory(_ area: ScreenRect) {
        painter.fill(area, radius: 12 * scale, color: RGBA(0, 0, 0, 40))
        if history.isEmpty {
            painter.textCentered(.body, in: area, text(.noTurnsYet), color: Self.mutedColor)
            return
        }
        let inner = area.inset(by: 9 * scale)
        var lines: [(text: String, kind: Int, first: Bool)] = []
        for entry in history.suffix(120) {
            for (index, line) in wrapText(entry.text, width: inner.width - 16 * scale).enumerated() {
                lines.append((line, entry.kind, index == 0))
            }
        }
        let rowHeight = (22 * scale).rounded()
        let visible = max(1, Int(inner.height / rowHeight))
        let maxScroll = Float(max(0, lines.count - visible))
        if area.contains(pointer.x, pointer.y) && pointer.scroll != 0 && !helpVisible {
            historyScroll = min(max(historyScroll - pointer.scroll * 3, 0), maxScroll)
            followHistory = historyScroll >= maxScroll
            pointer.scroll = 0
            pointer.zoom = 0
        }
        if followHistory {
            historyScroll = maxScroll
        }
        historyScroll = min(max(historyScroll, 0), maxScroll)
        let first = Int(historyScroll)
        for i in first..<min(lines.count, first + visible) {
            let line = lines[i]
            let y = inner.y + Float(i - first) * rowHeight
            let color = line.kind == 2 ? Self.noteColor : line.kind == 3 ? accent : Self.textColor
            if line.first {
                if line.kind <= 1 {
                    painter.disc(x: inner.x + 4 * scale, y: y + rowHeight / 2, radius: 3.5 * scale,
                                 color: RGBA(linear: theme.checkers[line.kind].color * 1.25 + SIMD3(repeating: 0.03)))
                } else {
                    painter.disc(x: inner.x + 4 * scale, y: y + rowHeight / 2, radius: 2.5 * scale, color: color.faded(0.7))
                }
            }
            painter.text(.body, x: inner.x + 16 * scale, y: y + (rowHeight - painter.lineHeight(.body)) / 2, line.text,
                         color: i == lines.count - 1 || line.kind >= 2 ? color : color.faded(0.82))
        }
        if maxScroll > 0 {
            let barHeight = inner.height * Float(visible) / Float(lines.count)
            let barY = inner.y + (inner.height - barHeight) * (historyScroll / maxScroll)
            painter.fill(ScreenRect(x: area.right - 5 * scale, y: barY, width: 3 * scale, height: barHeight), radius: 1.5 * scale,
                         color: RGBA(255, 255, 255, 50))
        }
    }
}
