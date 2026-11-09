import simd

/// Building the surfaces of the scene out of triangles.
extension Mesh where Vertex == SurfaceVertex {
    /// Adds a triangle, wound counterclockwise as seen from the side its normals face.
    mutating func addTriangle(_ a: SurfaceVertex, _ b: SurfaceVertex, _ c: SurfaceVertex) {
        let base = UInt32(vertices.count)
        vertices += [a, b, c]
        let facing = cross(b.position - a.position, c.position - a.position)
        if dot(facing, a.normal + b.normal + c.normal) >= 0 {
            indices += [base, base + 1, base + 2]
        } else {
            indices += [base, base + 2, base + 1]
        }
    }

    mutating func addQuad(_ a: SurfaceVertex, _ b: SurfaceVertex, _ c: SurfaceVertex, _ d: SurfaceVertex) {
        addTriangle(a, b, c)
        addTriangle(a, c, d)
    }
}
