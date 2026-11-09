import simd

/// A checker or a die to draw.
struct PieceDraw {
    enum Kind {
        case checker, die
    }

    /// With the size as its scale.
    var model = Matrix.identity
    var kind = Kind.checker
    /// White's (0) or Black's (1).
    var side = 0
    /// The number a die shows on top.
    var value = 0
    /// A glow at the rim: what may be moved, or is chosen.
    var highlight: Float = 0
    /// A die already played is darkened.
    var dim: Float = 0
}
