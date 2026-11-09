import AppKit
import simd

/// The mouse and the keys: the view hands the events over, the frame acts on them.
extension GameController {
    enum PointerButton {
        case left, right
    }

    // MARK: - Pointer events

    func pointerMoved(x: Float, y: Float) {
        pointer.x = x
        pointer.y = y
        requestFrame()
    }

    func pointerButton(_ button: PointerButton, down: Bool, x: Float, y: Float, doubleClick: Bool) {
        pointerMoved(x: x, y: y)
        switch button {
        case .left:
            pointer.leftDown = down
            if down {
                pointer.leftPressed = true
                pointer.doubleClick = doubleClick
            } else {
                pointer.leftReleased = true
            }
        case .right:
            pointer.rightDown = down
            if down {
                pointer.rightPressed = true
            } else {
                pointer.rightReleased = true
            }
        }
    }

    /// The pointer left the view: nothing stays highlighted under it, unless a button is held.
    func pointerLeft() {
        if !pointer.leftDown && !pointer.rightDown {
            pointer.x = -1
            pointer.y = -1
        }
        requestFrame()
    }

    /// The window lost the keyboard: a button let go of in another window is not heard here.
    func releaseButtons() {
        if pointer.leftDown {
            pointer.leftReleased = true
        }
        if pointer.rightDown {
            pointer.rightReleased = true
        }
        pointer.leftDown = false
        pointer.rightDown = false
        requestFrame()
    }

    /// Scrolling by a wheel or a trackpad, in notches as the content moves; `invertedByDevice` when the system turns
    /// the direction round ("natural" scrolling), which the zoom undoes, so that a push away zooms in either way.
    func scrolled(_ steps: Float, invertedByDevice: Bool) {
        pointer.scroll += steps
        pointer.zoom += invertedByDevice ? -steps : steps
        requestFrame()
    }

    /// A pinch on a trackpad, in notches of the wheel.
    func zoomed(_ steps: Float) {
        pointer.zoom += steps
        requestFrame()
    }

    // MARK: - The board under the pointer

    /// Where the ray through the pointer meets the level `height` above the field.
    private func pointerOnPlane(_ height: Float) -> SIMD3<Float>? {
        guard pointer.x >= 0, pointer.y >= 0 else { return nil }
        let ray = camera.ray(x: pointer.x, y: pointer.y, width: Float(width), height: Float(self.height))
        guard ray.direction.y <= -1e-4 else { return nil }
        let t = (height - ray.origin.y) / ray.direction.y
        return t < 0 ? nil : ray.origin + ray.direction * t
    }

    /// The place under the pointer, as `BoardView` counts places, or -1.
    private func placeUnderPointer() -> Int {
        guard let hit = pointerOnPlane(Board.checkerHeight) else { return -1 }
        let xz = SIMD2(hit.x, hit.z)
        let point = Board.pointAt(xz)
        if point >= 0 {
            return point
        }
        if abs(xz.x) < Board.barHalf && abs(xz.y) < Board.halfDepth {
            return BoardView.barPlace
        }
        let trayLeft = Board.fieldRight + Board.rimWidth * 0.5
        if xz.x > trayLeft && xz.x < trayLeft + Board.rimWidth + Board.trayWidth && abs(xz.y) < Board.halfDepth + Board.rimWidth {
            return BoardView.offPlace
        }
        return -1
    }

    /// The board hears the pointer the interface left: a checker chosen and moved by clicks or dragged, a step taken
    /// back, the dice thrown, the view turned and zoomed.
    func handleBoardPointer() {
        let free = !pointer.consumed && !helpVisible
        hoverPlace = free && gesture != .turnCamera ? placeUnderPointer() : -1
        let moving = isHumanToMove && doneClock <= 0
        let next = moving ? nextSteps() : []
        func movable(_ place: Int) -> Bool {
            let point = fromPlace(place)
            return next.contains { $0.from == point }
        }
        let reachable = moving && selected >= 0 ? routes(from: fromPlace(selected)) : []
        func route(to place: Int) -> Route? { reachable.first { toPlace($0.to) == place } }
        let awaitingRoll = stage == .toRoll && isHuman(toPlay) && !autoRoll
        if hoverPlace >= 0 && (movable(hoverPlace) || route(to: hoverPlace) != nil) {
            cursorHand = true
        }
        if free && awaitingRoll && hoverPlace >= 0 {
            cursorHand = true
        }

        if free && gesture == .none && (pointer.leftPressed || pointer.rightPressed) {
            gesture = .press
            pressRight = !pointer.leftPressed
            pressX = pointer.x
            pressY = pointer.y
            dragX = pointer.x
            dragY = pointer.y
            pressPlace = hoverPlace
            pressDouble = pointer.doubleClick
        }

        if gesture == .press {
            let moved = hypot(pointer.x - pressX, pointer.y - pressY) > Self.dragStart * scale
            let down = pressRight ? pointer.rightDown : pointer.leftDown
            if moved && down {
                if !pressRight && moving && movable(pressPlace) {
                    gesture = .drag
                    select(pressPlace)
                } else {
                    gesture = .turnCamera
                }
            } else if !down {
                gesture = .none
                click(pressPlace, moving: moving, awaitingRoll: awaitingRoll, movable: movable(pressPlace), route: route(to: pressPlace))
            }
        }

        if gesture == .turnCamera {
            if pressRight ? pointer.rightDown : pointer.leftDown {
                camera.rotate(yaw: -(pointer.x - dragX) * 0.006 / scale, pitch: (pointer.y - dragY) * 0.005 / scale)
                dragX = pointer.x
                dragY = pointer.y
            } else {
                gesture = .none
            }
        }

        if gesture == .drag {
            if !moving || selected < 0 {
                gesture = .none
                boardView.carry(nil)
            } else if pointer.leftDown {
                if let at = pointerOnPlane(0.03) {
                    boardView.carry(at)
                }
            } else {
                // Dropped: where it may go, else back to its place.
                gesture = .none
                if let route = route(to: placeUnderPointer()) {
                    playRoute(route)
                } else {
                    putBack()
                }
            }
        }

        if !pointer.consumed && !helpVisible && pointer.zoom != 0 {
            camera.zoom(pointer.zoom)
        }
    }

    /// A press let go of where it began, on `place`.
    private func click(_ place: Int, moving: Bool, awaitingRoll: Bool, movable: Bool, route: Route?) {
        if pressRight {
            if isHumanToMove && !played.isEmpty {
                takeBackStep()
            } else {
                select(-1)
            }
        } else if awaitingRoll {
            if place >= 0 {
                rollDice()
            }
        } else if moving {
            let toggled = toggledPlace
            toggledPlace = -1
            if pressDouble && toggled == place && movable {
                playLargerDie(from: fromPlace(place))
            } else if selected >= 0, let route {
                playRoute(route)
            } else if movable {
                select(place == selected ? -1 : place)
                toggledPlace = place
            } else {
                let mover = moverView
                let point = fromPlace(place)
                let own = point == Nardy.fromBar ? mover.bar[0] > 0 : point >= 0 && point < Nardy.points && mover.points[point] > 0
                if own {
                    showToast(whyNot(point))
                }
                select(-1)
            }
        }
    }

    /// The checker carried goes back to its place.
    private func putBack() {
        boardView.move(side: toPlay, from: selected, to: selected)
        select(-1)
    }

    // MARK: - Keys

    /// Acts on a key; false for the keys the game does not use, which the menus may take.
    @discardableResult
    func keyDown(_ key: KeyPress) -> Bool {
        requestFrame()
        if helpVisible {
            // Over the help only its own keys work, and full screen.
            if key.code == KeyPress.Code.escape || key.code == KeyPress.Code.f1 || key.code == KeyPress.Code.help {
                helpVisible = false
                return true
            }
            if key.code == KeyPress.Code.f11 {
                toggleFullScreen()
                return true
            }
            return !(key.command || key.control)
        }
        if key.command || key.control {
            switch key.letter {
            case "z":
                undo()
            case "n":
                newGame()
            default:
                return false
            }
            return true
        }

        switch key.code {
        case KeyPress.Code.returnKey where key.option:
            toggleFullScreen()
            return true
        case KeyPress.Code.space, KeyPress.Code.returnKey, KeyPress.Code.keypadEnter:
            if stage == .toRoll && isHuman(toPlay) {
                rollDice()
            } else if isHumanToMove && doneClock > 0 {
                endTurn()
            }
            return true
        case KeyPress.Code.delete:
            if isHumanToMove && !played.isEmpty {
                takeBackStep()
            } else {
                undo()
            }
            return true
        case KeyPress.Code.home:
            camera.reset()
            return true
        case KeyPress.Code.tab:
            togglePanel()
            return true
        case KeyPress.Code.f1, KeyPress.Code.help:
            helpVisible.toggle()
            return true
        case KeyPress.Code.f11:
            toggleFullScreen()
            return true
        case KeyPress.Code.escape:
            if gesture == .drag {
                gesture = .none
                putBack()
            } else if selected >= 0 {
                select(-1)
            } else if isFullScreen {
                toggleFullScreen()
            }
            return true
        default:
            break
        }
        if let level = key.level {
            setLevel(level)
            return true
        }
        let step = key.shift ? -1 : 1
        switch key.letter {
        case "h": requestHint()
        case "a": setAutoRoll(!autoRoll)
        case "c": setCamera(camera.mode.rawValue + 1)
        case "n": newGame()
        case "g": setGame(game.rawValue + 1)
        case "m": setMode(mode.rawValue + step)
        case "t": setTheme(themeIndex + step)
        case "v": toggleSound()
        case "l": toggleLanguage()
        default: return false
        }
        return true
    }
}
