/// The look of one side's checkers.
struct CheckerLook: Sendable {
    var color: SIMD3<Float>
    var roughness: Float = 0.3
    var clearcoat: Float = 0.7
    /// 0 plain, 1 wood, 2 stone, 3 bone.
    var pattern: Float = 0
    /// How deep the rosette is carved.
    var ornament: Float = 0.6
}
