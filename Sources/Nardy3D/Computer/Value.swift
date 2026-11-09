/// What a position is worth to the player to move: the chances of winning, of winning a gammon (марс) and of losing
/// one.
struct Value: Sendable {
    var win: Float = 0.5
    var winGammon: Float = 0
    var loseGammon: Float = 0

    /// In points per game.
    var equity: Float { 2 * win - 1 + winGammon - loseGammon }

    /// The same seen by the other player.
    var flipped: Value { Value(win: 1 - win, winGammon: loseGammon, loseGammon: winGammon) }
}
