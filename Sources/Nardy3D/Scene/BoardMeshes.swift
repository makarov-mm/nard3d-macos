/// The meshes of the board, each drawn as its own material.
struct BoardMeshes {
    /// The two playing surfaces; the shader draws the points on them.
    var field = Mesh<SurfaceVertex>()
    /// The rims, the middle bar, the base and the tray.
    var wood = Mesh<SurfaceVertex>()
    /// The floors of the tray's compartments.
    var felt = Mesh<SurfaceVertex>()
    /// The table the board stands on.
    var table = Mesh<SurfaceVertex>()
}
