import simd

/// Everything the renderer draws in a frame, but the interface.
struct RenderScene {
    var view = Matrix.identity
    var projection = Matrix.identity
    var eye = SIMD3<Float>(repeating: 0)
    var time: Float = 0
    var pieces: [PieceDraw] = []
    /// For each point as White counts them: x a place to move to, y a checker that may move, z the last move, w the
    /// hint.
    var points = [SIMD4<Float>](repeating: .zero, count: Nardy.points)
    /// x White's tray as a place to move to, y Black's; z the hint into White's (above 0) or Black's (below).
    var trays = SIMD4<Float>(repeating: 0)
    var panels: [FrostedPanel] = []
}
