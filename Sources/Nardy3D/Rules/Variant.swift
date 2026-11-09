/// The two games: long nardy, where both sides run the same way round the board and a single checker holds a point,
/// and short nardy (backgammon), where they run against each other and a lone checker can be hit.
enum Variant: Int, Sendable {
    case long = 0
    case short = 1
}
