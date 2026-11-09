/// The looks of the board, the checkers, the dice, the table under them and the lamp over it.
struct Theme: Sendable {
    var englishName: String
    var russianName: String

    // The fields and the points inlaid in them.
    var field: SIMD3<Float>
    var fieldRoughness: Float = 0.45
    /// 0 wood, 1 felt, 2 leather.
    var fieldPattern: Float = 0
    var fieldSeed: Float = 0.3
    var fieldClearcoat: Float = 0.5
    var pointA: SIMD3<Float>
    var pointB: SIMD3<Float>
    var pointRoughness: Float = 0.45
    var lineWidth: Float = 0.0006
    var lineMetallic: Float = 1
    var line: SIMD3<Float>
    // The rims, the bar and the tray.
    var wood: SIMD3<Float>
    var woodRoughness: Float = 0.3
    var woodClearcoat: Float = 0.8
    /// 0 wood, 1 lacquer.
    var woodPattern: Float = 0
    var woodSeed: Float = 0.5
    var felt: SIMD3<Float>
    // The table under the board.
    var table: SIMD3<Float>
    var tableRoughness: Float = 0.5
    /// 0 wood, 1 cloth, 2 stone.
    var tablePattern: Float = 0
    var tableSeed: Float = 0.2

    /// White's and Black's.
    var checkers: [CheckerLook]
    var die: SIMD3<Float>
    var dieRoughness: Float = 0.25
    var pip: SIMD3<Float>

    // The light.
    var keyDirection: SIMD3<Float>
    var keyRadiance: SIMD3<Float>
    /// Tangent of the light's angular radius.
    var keySoftness: Float = 0.15
    var ceiling: SIMD3<Float>
    var horizon: SIMD3<Float>
    var ground: SIMD3<Float>
    var panels: [StudioPanel] = []
    var diffuseLight: Float = 1
    var reflectedLight: Float = 1
    var background: Float = 0.5
    var fog: SIMD3<Float>
    var exposure: Float = 1
    var bloom: Float = 0.04
    var vignette: Float = 0.45

    /// Where a checker may go, the chosen checker and the interface.
    var accent: SIMD3<Float>
    /// The computer's advice.
    var hint: SIMD3<Float>

    func name(_ language: Language) -> String { language == .russian ? russianName : englishName }

    /// The lamp over the board, and a dim room round it.
    mutating func light(lamp radiance: SIMD3<Float>, fill: SIMD3<Float>) {
        panels = [
            StudioPanel(direction: SIMD3(0, 1, 0), halfSize: SIMD2(0.26, 0.2), corner: 0.45, softness: 0.1, radiance: radiance * 1.6),
            StudioPanel(direction: SIMD3(0, 1, 0), halfSize: SIMD2(1.4, 0.9), corner: 0.3, softness: 0.6, radiance: radiance * 0.08),
            StudioPanel(direction: SIMD3(0.9, 0.25, 0.35), halfSize: SIMD2(0.8, 0.3), corner: 0.1, softness: 0.3, radiance: fill),
            StudioPanel(direction: SIMD3(-0.9, 0.25, -0.35), halfSize: SIMD2(0.8, 0.3), corner: 0.1, softness: 0.3, radiance: fill * 0.7),
            StudioPanel(direction: SIMD3(0.1, 0.3, 0.95), halfSize: SIMD2(1.2, 0.25), corner: 0.1, softness: 0.4, radiance: fill * 0.5),
        ]
    }
}
