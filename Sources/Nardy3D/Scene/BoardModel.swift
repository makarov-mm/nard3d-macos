import Foundation
import simd

/// The meshes of the scene: the board in two halves with its rims, the middle bar and the tray for the checkers
/// borne off, the table under it, the checker and the die.
enum BoardModel {
    /// A point of an outline in 2D, with its normal and its distance along the outline.
    private struct OutlineVertex {
        var point: SIMD2<Float>
        var normal: SIMD2<Float>
        var along: Float
    }

    static func board() -> BoardMeshes {
        var meshes = BoardMeshes()
        let fieldRight = Board.fieldRight
        let halfDepth = Board.halfDepth

        // The two playing surfaces; the points are drawn on them.
        for side: Float in [-1, 1] {
            func v(_ x: Float, _ z: Float) -> SurfaceVertex { SurfaceVertex(SIMD3(x, 0, z), SIMD3(0, 1, 0), SIMD2(x, z)) }
            let x0 = side * Board.barHalf
            let x1 = side * fieldRight
            meshes.field.addQuad(v(x0, -halfDepth), v(x1, -halfDepth), v(x1, halfDepth), v(x0, halfDepth))
        }

        // The rim round the board, the middle bar between the halves, and the base under them.
        let rim = rimOutline(width: Board.rimWidth)
        let corners: [SIMD2<Float>] = [SIMD2(-fieldRight, halfDepth), SIMD2(fieldRight, halfDepth), SIMD2(fieldRight, -halfDepth),
                                       SIMD2(-fieldRight, -halfDepth)]
        let outwards: [SIMD2<Float>] = [SIMD2(0, 1), SIMD2(1, 0), SIMD2(0, -1), SIMD2(-1, 0)]
        for k in 0..<4 {
            sweep(&meshes.wood, from: corners[k], to: corners[(k + 1) % 4], outward: outwards[k], outline: rim, mitreStart: true, mitreEnd: true)
        }
        var bar: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(0, Board.rimHeight - 0.004)]
        for k in 1...4 {
            let angle = Float.pi / 2 * Float(k) / 4
            bar.append(SIMD2(0.004 - 0.004 * cos(angle), Board.rimHeight - 0.004 + 0.004 * sin(angle)))
        }
        bar.append(SIMD2(Board.barHalf, Board.rimHeight))
        // Each half of the bar from its field's edge to the middle line.
        for side: Float in [-1, 1] {
            sweep(&meshes.wood, from: SIMD2(side * Board.barHalf, -halfDepth), to: SIMD2(side * Board.barHalf, halfDepth), outward: SIMD2(-side, 0),
                  outline: bar, mitreStart: false, mitreEnd: false)
        }
        let outer = Board.outer
        let trayInner = Board.trayInner
        let trayOuter = Board.trayOuter
        let trayWall = Board.trayWall
        addBox(&meshes.wood, SIMD3(-fieldRight - Board.rimWidth, -Board.base, -outer), SIMD3(trayOuter, -0.001, outer), top: false)

        // The tray beside the right half: an outer wall, end walls, a divider, and a floor of felt in each compartment.
        addBox(&meshes.wood, SIMD3(trayOuter - trayWall, -Board.base, -outer), SIMD3(trayOuter, Board.rimHeight, outer))
        for z in [-outer, outer - trayWall] {
            addBox(&meshes.wood, SIMD3(trayInner, -Board.base, z), SIMD3(trayOuter - trayWall, Board.rimHeight, z + trayWall))
        }
        addBox(&meshes.wood, SIMD3(trayInner, -Board.base, -trayWall / 2), SIMD3(trayOuter - trayWall, Board.rimHeight, trayWall / 2))
        addBox(&meshes.wood, SIMD3(trayInner, -Board.base, -outer), SIMD3(trayOuter - trayWall, Board.trayFloor - 0.0005, outer), top: false)
        for side: Float in [-1, 1] {
            func v(_ x: Float, _ z: Float) -> SurfaceVertex { SurfaceVertex(SIMD3(x, Board.trayFloor, z), SIMD3(0, 1, 0), SIMD2(x, z)) }
            let z0 = side * trayWall / 2
            let z1 = side * (outer - trayWall)
            meshes.felt.addQuad(v(trayInner, z0), v(trayOuter - trayWall, z0), v(trayOuter - trayWall, z1), v(trayInner, z1))
        }

        // The table, wide enough to fill the view.
        func t(_ x: Float, _ z: Float) -> SurfaceVertex { SurfaceVertex(SIMD3(x, -Board.base, z), SIMD3(0, 1, 0), SIMD2(x, z)) }
        meshes.table.addQuad(t(-4, -4), t(4, -4), t(4, 4), t(-4, 4))
        return meshes
    }

    /// A checker of radius 1 lying on y = 0, its top at `Board.checkerHeight / Board.checkerRadius`. The second
    /// texture coordinate is the distance along its outline.
    static func checker() -> Mesh<SurfaceVertex> {
        // Rounded edges, a raised ring round the top and a shallow dish inside it with a carved groove.
        let h = Board.checkerHeight / Board.checkerRadius
        var outline: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(0.9, 0)]
        func arc(_ center: SIMD2<Float>, _ radius: Float, _ from: Float, _ to: Float, _ steps: Int) {
            for k in 1...steps {
                let angle = from + (to - from) * Float(k) / Float(steps)
                outline.append(SIMD2(center.x + radius * cos(angle), center.y + radius * sin(angle)))
            }
        }
        arc(SIMD2(0.9, 0.1), 0.1, -Float.pi / 2, 0, 4)
        outline.append(SIMD2(1.0, h - 0.1))
        arc(SIMD2(0.9, h - 0.1), 0.1, 0, Float.pi / 2, 4)
        outline.append(SIMD2(0.8, h))
        arc(SIMD2(0.8, h - 0.04), 0.04, Float.pi / 2, Float.pi, 3)
        outline.append(SIMD2(0.74, h - 0.06))
        outline.append(SIMD2(0.5, h - 0.065))
        outline.append(SIMD2(0.46, h - 0.1))
        outline.append(SIMD2(0.42, h - 0.065))
        outline.append(SIMD2(0, h - 0.06))
        return lathe(outline, turns: 48)
    }

    /// A die with rounded edges, its faces at ±1.
    static func die() -> Mesh<SurfaceVertex> {
        // A cube whose edges and corners are rounded off: each face a grid packed toward its edges, every vertex pushed
        // out to the rounded surface.
        let grid = 18
        let round: Float = 0.2
        var mesh = Mesh<SurfaceVertex>()
        let axes: [SIMD3<Float>] = [SIMD3(1, 0, 0), SIMD3(-1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, -1, 0), SIMD3(0, 0, 1), SIMD3(0, 0, -1)]
        for n in axes {
            let u: SIMD3<Float> = abs(n.y) > 0.5 ? SIMD3(1, 0, 0) : SIMD3(0, 1, 0)
            let v = cross(n, u)
            let base = UInt32(mesh.vertices.count)
            for i in 0...grid {
                for j in 0...grid {
                    let a = sin((Float(i) / Float(grid) * 2 - 1) * Float.pi / 2)
                    let b = sin((Float(j) / Float(grid) * 2 - 1) * Float.pi / 2)
                    let p = n + u * a + v * b
                    let inner = SIMD3(min(max(p.x, round - 1), 1 - round), min(max(p.y, round - 1), 1 - round), min(max(p.z, round - 1), 1 - round))
                    let normal = Matrix.unit(p - inner)
                    mesh.vertices.append(SurfaceVertex(inner + normal * round, normal, SIMD2(a, b)))
                }
            }
            for i in 0..<grid {
                for j in 0..<grid {
                    func at(_ di: Int, _ dj: Int) -> UInt32 { base + UInt32((i + di) * (grid + 1) + j + dj) }
                    // Counterclockwise from outside: u × v points along the normal.
                    mesh.indices += [at(0, 0), at(1, 0), at(1, 1), at(0, 0), at(1, 1), at(0, 1)]
                }
            }
        }
        return mesh
    }

    // MARK: - Shapes

    /// A box; without its top where something lies on it.
    private static func addBox(_ mesh: inout Mesh<SurfaceVertex>, _ low: SIMD3<Float>, _ high: SIMD3<Float>, top: Bool = true) {
        let c: [SIMD3<Float>] = [
            SIMD3(low.x, low.y, low.z), SIMD3(high.x, low.y, low.z), SIMD3(high.x, high.y, low.z), SIMD3(low.x, high.y, low.z),
            SIMD3(low.x, low.y, high.z), SIMD3(high.x, low.y, high.z), SIMD3(high.x, high.y, high.z), SIMD3(low.x, high.y, high.z),
        ]
        func face(_ a: Int, _ b: Int, _ d: Int, _ e: Int, _ normal: SIMD3<Float>) {
            func v(_ i: Int) -> SurfaceVertex { SurfaceVertex(c[i], normal, SIMD2(c[i].x + c[i].z, c[i].y + c[i].z)) }
            mesh.addQuad(v(a), v(b), v(d), v(e))
        }
        face(0, 1, 2, 3, SIMD3(0, 0, -1))
        face(4, 5, 6, 7, SIMD3(0, 0, 1))
        face(0, 4, 7, 3, SIMD3(-1, 0, 0))
        face(1, 5, 6, 2, SIMD3(1, 0, 0))
        face(0, 1, 5, 4, SIMD3(0, -1, 0))
        if top {
            face(3, 2, 6, 7, SIMD3(0, 1, 0))
        }
    }

    /// The segments of a 2D outline that runs counterclockwise round a solid, with their normals: across each
    /// segment, turned a quarter to the right of its direction, and shared where neighbouring segments meet at a
    /// slight angle, so that rounded parts shade smoothly and sharp ones stay sharp.
    private static func segments(_ outline: [SIMD2<Float>]) -> [(start: OutlineVertex, end: OutlineVertex)] {
        var normals: [SIMD2<Float>] = []
        for i in 0..<(outline.count - 1) {
            let d = outline[i + 1] - outline[i]
            let size = max(length(d), 1e-9)
            normals.append(SIMD2(d.y / size, -d.x / size))
        }
        var result: [(start: OutlineVertex, end: OutlineVertex)] = []
        var along: Float = 0
        for i in normals.indices {
            func shared(_ other: Int) -> SIMD2<Float> {
                let sum = normals[i] + normals[other]
                return dot(normals[i], normals[other]) > 0.77 ? sum * (1 / length(sum)) : normals[i]
            }
            let n0 = i > 0 ? shared(i - 1) : normals[i]
            let n1 = i + 1 < normals.count ? shared(i + 1) : normals[i]
            let size = length(outline[i + 1] - outline[i])
            result.append((OutlineVertex(point: outline[i], normal: n0, along: along),
                           OutlineVertex(point: outline[i + 1], normal: n1, along: along + size)))
            along += size
        }
        return result
    }

    /// A surface of revolution round the y axis from an outline of (radius, height), listed from the axis at the
    /// bottom round the outside to the axis at the top.
    private static func lathe(_ outline: [SIMD2<Float>], turns: Int) -> Mesh<SurfaceVertex> {
        var mesh = Mesh<SurfaceVertex>()
        for segment in segments(outline) {
            let base = UInt32(mesh.vertices.count)
            for v in [segment.start, segment.end] {
                for j in 0...turns {
                    let t = Float(j) / Float(turns)
                    let c = cos(2 * Float.pi * t)
                    let s = sin(2 * Float.pi * t)
                    mesh.vertices.append(SurfaceVertex(SIMD3(v.point.x * c, v.point.y, v.point.x * s),
                                                       Matrix.unit(SIMD3(v.normal.x * c, v.normal.y, v.normal.x * s)), SIMD2(t, v.along)))
                }
            }
            let row = UInt32(turns + 1)
            for j in 0..<UInt32(turns) {
                let a = base + j
                let b = base + j + 1
                let c = base + row + j + 1
                let d = base + row + j
                // Counterclockwise seen from outside, with the outline running upward on the outside.
                mesh.indices += [a, c, b, a, d, c]
            }
        }
        return mesh
    }

    /// A rim along the straight edge from `start` to `end` of the plane y = 0 (as x, z), `outward` pointing away from
    /// the field, with the cross-section `outline` of (distance outward, height) running up from the field and over
    /// the top, the other way round from a lathe's outline. Its ends are cut at 45 degrees where the mitres say, so
    /// that four make a frame.
    private static func sweep(_ mesh: inout Mesh<SurfaceVertex>, from start: SIMD2<Float>, to end: SIMD2<Float>, outward: SIMD2<Float>,
                              outline: [SIMD2<Float>], mitreStart: Bool, mitreEnd: Bool) {
        let span = end - start
        let along = span * (1 / length(span))
        func place(_ p: SIMD2<Float>, atEnd: Bool) -> SIMD3<Float> {
            let extend = (atEnd ? mitreEnd : mitreStart) ? p.x : 0
            let at = (atEnd ? end + along * extend : start - along * extend) + outward * p.x
            return SIMD3(at.x, p.y, at.y)
        }
        for segment in segments(outline) {
            func vertex(_ v: OutlineVertex, atEnd: Bool) -> SurfaceVertex {
                let position = place(v.point, atEnd: atEnd)
                let normal = Matrix.unit(SIMD3(-outward.x * v.normal.x, -v.normal.y, -outward.y * v.normal.x))
                return SurfaceVertex(position, normal, SIMD2(dot(SIMD2(position.x, position.z), along), v.along))
            }
            mesh.addQuad(vertex(segment.start, atEnd: false), vertex(segment.end, atEnd: false), vertex(segment.end, atEnd: true),
                         vertex(segment.start, atEnd: true))
        }
    }

    /// The cross-section of a rim: up from the field, a rounded top, and down the outside to the bottom of the base.
    private static func rimOutline(width: Float) -> [SIMD2<Float>] {
        var outline: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(0, Board.rimHeight - 0.004)]
        let round: Float = 0.004
        for k in 1...4 {
            let angle = Float.pi / 2 * Float(k) / 4
            outline.append(SIMD2(round - round * cos(angle), Board.rimHeight - round + round * sin(angle)))
        }
        let outer: Float = 0.007
        outline.append(SIMD2(width - outer, Board.rimHeight))
        for k in 1...6 {
            let angle = Float.pi / 2 * Float(k) / 6
            outline.append(SIMD2(width - outer + outer * sin(angle), Board.rimHeight - outer + outer * cos(angle)))
        }
        outline.append(SIMD2(width, -Board.base))
        return outline
    }
}
