import AppKit

/// The cards over the game: the banner, the toasts and the help; and the words for the players and the game's state.
extension GameController {
    /// The rows in each of the help's two columns.
    private static let helpRows = 11
    private static let helpWidth: Float = 900
    private static let helpRow: Float = 26
    private static let helpPad: Float = 28

    private var rules: Str { game == .long ? .rulesLong : .rulesShort }

    /// The words of a text in lines no wider than `width`.
    func wrapText(_ text: String, width: Float) -> [String] {
        var lines: [String] = []
        var line = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: false) {
            let longer = line.isEmpty ? String(word) : line + " " + word
            if !line.isEmpty && painter.measure(.body, longer) > width {
                lines.append(line)
                line = String(word)
            } else {
                line = longer
            }
        }
        if !line.isEmpty {
            lines.append(line)
        }
        return lines
    }

    var helpCard: ScreenRect {
        let free = freeArea
        let width = min(Self.helpWidth * scale, free.width - 20 * scale)
        let rows = Float(Self.helpRows + 1 + wrapText(text(rules), width: width - 2 * Self.helpPad * scale).count)
        let height = (2 * Self.helpPad + 44 + 12) * scale + rows * Self.helpRow * scale
        return ScreenRect(x: free.x + (free.width - width) / 2, y: max(10 * scale, (Float(self.height) - height) / 2), width: width, height: height)
    }

    var bannerCard: ScreenRect {
        let width = max(painter.measure(.display, bannerTitle) + 80 * scale, painter.measure(.body, bannerDetail) + 60 * scale, 320 * scale)
        let free = freeArea
        return ScreenRect(x: free.x + (free.width - width) / 2, y: 26 * scale - (1 - bannerFade) * 20 * scale, width: width, height: 92 * scale)
    }

    /// The help, from the menu.
    func showHelp() {
        helpVisible = true
        requestFrame()
    }

    func showToast(_ text: String) {
        if toasts.count >= 3 {
            toasts.removeFirst()
        }
        toasts.append(Toast(text: text))
    }

    /// A title and a line under it, for `seconds`; below zero, until another.
    func showBanner(_ title: String, _ detail: String, seconds: Float) {
        bannerTitle = title
        bannerDetail = detail
        bannerTime = seconds
    }

    func drawBanner() {
        guard bannerFade > 0.001 else { return }
        let card = bannerCard
        painter.shadow(card, blur: 24 * scale, color: RGBA(0, 0, 0, 120).faded(bannerFade))
        painter.fill(card, radius: 18 * scale, color: RGBA(14, 16, 24, 150).faded(bannerFade))
        painter.outline(card, radius: 18 * scale, color: accent.faded(0.6 * bannerFade))
        painter.textCentered(.display, in: ScreenRect(x: card.x, y: card.y + 8 * scale, width: card.width, height: 48 * scale), bannerTitle,
                             color: Self.textColor.faded(bannerFade))
        painter.textCentered(.body, in: ScreenRect(x: card.x, y: card.y + 54 * scale, width: card.width, height: 26 * scale), bannerDetail,
                             color: Self.mutedColor.faded(bannerFade))
    }

    func drawHelp() {
        painter.fill(ScreenRect(x: 0, y: 0, width: Float(width), height: Float(height)), radius: 0, color: RGBA(0, 0, 0, 110))
        let lines: [(keys: String, action: Str)] = [
            (text(.keyClick), .helpClick),
            (text(.keyDrag), .helpDrag),
            (text(.keyDoubleClick), .helpDoubleClick),
            (text(.keyRightClick), .helpTakeBack),
            (text(.keyRightDrag), .helpRotate),
            (text(.keyWheel), .helpZoom),
            ("Space  Return", .helpRoll),
            ("H", .helpHint),
            ("⌘Z", .helpUndo),
            ("A", .helpAutoRoll),
            ("C  Home", .helpCamera),
            ("N", .helpNew),
            ("G", .helpGame),
            ("M", .helpMode),
            ("1 – 5", .helpLevel),
            ("T", .helpTheme),
            ("V", .helpSound),
            ("L", .helpLanguage),
            ("Tab", .helpPanel),
            ("⌃⌘F  F11", .helpFullScreen),
            ("Esc  F1", .helpClose),
        ]
        let rowHeight = Self.helpRow * scale
        let pad = Self.helpPad * scale
        let card = helpCard
        painter.shadow(card, blur: 26 * scale, color: RGBA(0, 0, 0, 140))
        painter.fill(card, radius: 20 * scale, color: RGBA(18, 20, 28, 175))
        painter.outline(card, radius: 20 * scale, color: RGBA(255, 255, 255, 30))
        painter.text(.heading, x: card.x + pad, y: card.y + pad - 4 * scale, text(.controls), color: Self.textColor)
        let top = card.y + pad + 44 * scale
        let leftWidth = (card.width - 2 * pad) * 0.57
        for (i, line) in lines.enumerated() {
            let second = i >= Self.helpRows - 1
            let columnX = card.x + pad + (second ? leftWidth : 0)
            let y = top + Float(second ? i - (Self.helpRows - 1) : i) * rowHeight
            let keysWidth = (second ? 130 : 228) * scale
            painter.text(.body, x: columnX, y: y, line.keys, color: accent)
            painter.text(.body, x: columnX + keysWidth, y: y, text(line.action), color: Self.textColor)
        }
        // The rules of the game on the board, in a few sentences.
        var y = top + Float(Self.helpRows) * rowHeight + 12 * scale
        painter.text(.body, x: card.x + pad, y: y, text(.rules), color: accent)
        for line in wrapText(text(rules), width: card.width - 2 * pad) {
            y += rowHeight
            painter.text(.body, x: card.x + pad, y: y, line, color: Self.mutedColor)
        }
        if button(Widget.helpClose, ScreenRect(x: card.right - pad - 30 * scale, y: card.y + pad - 8 * scale, width: 30 * scale, height: 30 * scale), "×")
            || (pointer.leftPressed && !card.contains(pointer.x, pointer.y)) {
            helpVisible = false
        }
        if pointer.leftPressed || pointer.rightPressed {
            pointer.consumed = true
        }
    }

    func drawToasts() {
        let free = freeArea
        var y = Float(height) - 40 * scale
        for toast in toasts.reversed() {
            let fade = min(1, toast.age * 6, (2.8 - toast.age) * 3)
            let width = painter.measure(.body, toast.text) + 40 * scale
            let height = 36 * scale
            let pill = ScreenRect(x: free.x + (free.width - width) / 2, y: y - height, width: width, height: height)
            painter.shadow(pill, blur: 14 * scale, color: RGBA(0, 0, 0, 110).faded(fade))
            painter.fill(pill, radius: height / 2, color: RGBA(20, 22, 30, 225).faded(fade))
            painter.textCentered(.body, in: pill, toast.text, color: Self.textColor.faded(fade))
            y -= height + 8 * scale
        }
    }

    // MARK: - Words

    /// The words for one side: "you" or "the computer" against the computer, else "White" or "Black".
    func pick(_ side: Int, _ you: Str, _ computer: Str, _ white: Str, _ black: Str) -> String {
        if mode == .vsComputer {
            return text(side == 0 ? you : computer)
        }
        return text(side == 0 ? white : black)
    }

    func playerName(_ side: Int) -> String {
        pick(side, .nameYou, .nameComputer, .nameWhite, .nameBlack)
    }

    var statusTitle: String {
        switch stage {
        case .opening: text(.opening)
        case .over: pick(winner, .winYou, .winComputer, .winWhite, .winBlack)
        default: pick(toPlay, .turnYou, .turnComputer, .turnWhite, .turnBlack)
        }
    }

    var statusDetail: String {
        switch stage {
        case .opening:
            return text(.openingDetail)
        case .over:
            return text(mode == .demo ? .demoNext : .pressNew)
        case .toRoll:
            return text(isHuman(toPlay) && !autoRoll ? .rollPrompt : .rolling)
        case .rolling:
            return text(.rolling)
        case .thinking:
            return text(.thinking)
        case .playing:
            return text(.computerMoving)
        case .moving:
            break
        }
        if sequences.isEmpty {
            return text(.noMovesToast)
        }
        if doneClock > 0 {
            return text(.turnDone)
        }
        // The dice still to play.
        var dice = roll.dice
        for step in played {
            if let used = dice.firstIndex(of: step.die) {
                dice.remove(at: used)
            }
        }
        return text(.toPlay, dice.map(String.init).joined(separator: ", "))
    }
}
