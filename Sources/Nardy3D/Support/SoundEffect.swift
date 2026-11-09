/// The sounds of the game: dice shaken and striking the board, checkers set down, knocked off or dropped into the
/// tray, the checkers set out for a new game, and the interface.
enum SoundEffect: Int, CaseIterable {
    case rattle, die, checker, hit, tray, setup, click, noMove, win
}
