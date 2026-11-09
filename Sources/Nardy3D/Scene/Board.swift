/// The board's measurements and the places on it. The playing surface is the plane y = 0 with x to the right and z
/// toward White, who sits at the near side. Point w (0 to 23, as White counts them) lies along the near edge for
/// w < 12, from the right, and along the far edge from the left for the rest.
enum Board {
    static let pointWidth: Float = 0.042
    /// From the edge to the tip.
    static let pointLength: Float = 0.2
    /// From the middle to the near edge of the field.
    static let halfDepth: Float = 0.23
    /// Half the width of the middle bar.
    static let barHalf: Float = 0.028
    static let rimWidth: Float = 0.032
    static let rimHeight: Float = 0.022
    /// The board's thickness under the field.
    static let base: Float = 0.03
    /// The tray beside the right half.
    static let trayWidth: Float = 0.058
    static let checkerRadius: Float = 0.0192
    static let checkerHeight: Float = 0.0088
    /// Between the middles of neighbours along a point.
    static let checkerStep: Float = 0.0396
    /// Checkers along a point before they stack.
    static let rowLength = 5
    /// Half the edge of a die.
    static let dieSize: Float = 0.0175
    /// The field's outer edge.
    static let fieldRight = barHalf + 6 * pointWidth

    // The tray and the board's far and near edges.
    static let trayInner = fieldRight + rimWidth
    static let trayOuter = trayInner + trayWidth
    static let trayWall: Float = 0.008
    static let trayFloor: Float = 0.006
    static let outer = halfDepth + rimWidth

    /// The middle of point w's base on the field.
    static func pointBase(_ w: Int) -> SIMD3<Float> {
        let nearSide = w < 12
        let column = nearSide ? w : 23 - w // from the right
        let x = column < 6 ? barHalf + (5.5 - Float(column)) * pointWidth : -(barHalf + (Float(column) - 5.5) * pointWidth)
        return SIMD3(x, 0, nearSide ? halfDepth : -halfDepth)
    }

    /// Which way along z the tip of point w lies: +1 or -1.
    static func pointToward(_ w: Int) -> Float { w < 12 ? -1 : 1 }

    /// Where the index-th checker on point w lies: in a row toward the tip, then in towers.
    static func checkerSpot(_ w: Int, _ index: Int) -> SIMD3<Float> {
        let slot = index % rowLength
        let layer = index / rowLength
        var p = pointBase(w)
        p.z += pointToward(w) * ((Float(slot) + 0.5) * checkerStep + 0.002)
        p.y = Float(layer) * checkerHeight
        return p
    }

    /// On the middle bar: White's (side 0) toward the far side, where they enter; Black's toward the near side.
    static func barSpot(side: Int, _ index: Int) -> SIMD3<Float> {
        let slot = index % 4
        let layer = index / 4
        let z = 0.045 + Float(slot) * checkerStep
        return SIMD3(0, rimHeight + Float(layer) * checkerHeight, side == 0 ? -z : z)
    }

    /// Standing on edge in the tray: White's in the near compartment, Black's in the far one.
    static func offSpot(side: Int, _ index: Int) -> SIMD3<Float> {
        let z = outer - trayWall - 0.006 - (Float(index) + 0.5) * (checkerHeight + 0.0006)
        return SIMD3((trayInner + trayOuter - trayWall) / 2, trayFloor + checkerRadius, side == 0 ? z : -z)
    }

    /// Where a die thrown by `side` comes to rest: White's in the right half, Black's in the left.
    static func dieSpot(side: Int, _ index: Int) -> SIMD3<Float> {
        let x = barHalf + 3 * pointWidth + (index == 0 ? -0.032 : 0.034)
        let z: Float = index == 0 ? -0.006 : 0.009
        return SIMD3(side == 0 ? x : -x, dieSize, side == 0 ? z : -z)
    }

    /// The point under a place on the field, as x and z, or -1.
    static func pointAt(_ xz: SIMD2<Float>) -> Int {
        let ax = abs(xz.x)
        if ax < barHalf || ax > fieldRight || abs(xz.y) > halfDepth {
            return -1
        }
        let across = min(5, Int((ax - barHalf) / pointWidth))
        let column = xz.x > 0 ? 5 - across : 6 + across
        return xz.y > 0 ? column : 23 - column
    }
}
