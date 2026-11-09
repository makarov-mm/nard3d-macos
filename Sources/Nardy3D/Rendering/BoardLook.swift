import simd

/// The uniforms of the board shader, as BoardUniforms in Common.metal lays them out: the looks of a theme, then the
/// marks of a frame on the trays and on each point.
struct BoardLook {
    let layout: SIMD4<Float>
    let fieldColor: SIMD4<Float>
    let fieldStyle: SIMD4<Float>
    let pointColors: (SIMD4<Float>, SIMD4<Float>)
    let pointStyle: SIMD4<Float>
    let lineColor: SIMD4<Float>
    let woodColor: SIMD4<Float>
    let woodStyle: SIMD4<Float>
    let feltColor: SIMD4<Float>
    let tableColor: SIMD4<Float>
    let tableStyle: SIMD4<Float>
    let hintColor: SIMD4<Float>
    let trays: SIMD4<Float>
    let points: [SIMD4<Float>]

    init(theme t: Theme, scene: RenderScene) {
        layout = SIMD4(Board.pointWidth, Board.pointLength, Board.halfDepth, Board.barHalf)
        fieldColor = SIMD4(t.field, 0)
        fieldStyle = SIMD4(t.fieldRoughness, t.fieldPattern, t.fieldSeed, t.fieldClearcoat)
        pointColors = (SIMD4(t.pointA, 0), SIMD4(t.pointB, 0))
        pointStyle = SIMD4(t.pointRoughness, t.lineWidth, t.lineMetallic, 0)
        lineColor = SIMD4(t.line, 0)
        woodColor = SIMD4(t.wood, 0)
        woodStyle = SIMD4(t.woodRoughness, t.woodClearcoat, t.woodPattern, t.woodSeed)
        feltColor = SIMD4(t.felt, 0)
        tableColor = SIMD4(t.table, 0)
        tableStyle = SIMD4(t.tableRoughness, t.tablePattern, t.tableSeed, 0)
        hintColor = SIMD4(t.hint, 0)
        trays = scene.trays
        points = scene.points
    }

    /// The values in the shader's order, the points filled up to all 24.
    var packed: [SIMD4<Float>] {
        let marks = Array(points.prefix(Nardy.points)) + Array(repeating: SIMD4<Float>(repeating: 0), count: max(0, Nardy.points - points.count))
        return [layout, fieldColor, fieldStyle, pointColors.0, pointColors.1, pointStyle, lineColor, woodColor, woodStyle, feltColor, tableColor,
                tableStyle, hintColor, trays] + marks
    }
}
