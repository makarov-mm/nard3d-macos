/// A position as the player to move sees it: their checkers are counted above zero, the opponent's below. The player
/// to move brings their checkers from point 23 down to point 0, their home is points 0 to 5, and they bear off below
/// point 0. Points are numbered for people from 1, as the mover sees them.
struct Position: Equatable, Sendable {
    /// The checkers on the points 0 to 23. Kept inline, in a vector of which only the first 24 lanes are used, so
    /// that a position is copied without allocating: the search for moves makes thousands of them.
    var points = SIMD32<Int8>()
    /// On the bar, in short nardy only: the mover's, then the opponent's.
    var bar = SIMD2<Int8>()
    /// Borne off: the mover's, then the opponent's.
    var off = SIMD2<Int8>()
}
