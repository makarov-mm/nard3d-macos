import Foundation
import simd

/// A camera circling a point over the board. Its moves are eased: dragging, zooming and the views set where it heads.
/// The overview looks at the board from White's side at an angle; the other view from nearly straight above.
struct BoardCamera {
    private struct Pose {
        var target = SIMD3<Float>(repeating: 0)
        var yaw: Float = 0
        var pitch: Float = 1
        var distance: Float = 1
        var shift: Float = 0
        var space: Float = 1
    }

    private static let minPitch: Float = 0.12
    private static let maxPitch: Float = 1.5703
    private static let overviewPitch: Float = 0.9
    private static let fieldOfView: Float = 0.6
    /// Of the space for the board, below which the view widens.
    private static let minAspect: Float = 1.5
    private static let ease: Float = 7
    /// The middle of the board with its tray.
    private static let middle = SIMD3<Float>(0.03, 0, 0)

    private(set) var mode = CameraMode.overview
    private var pose = Pose()
    private var goal = Pose()

    init() {
        applyMode()
        pose = goal
    }

    mutating func setMode(_ mode: CameraMode) {
        self.mode = mode
        applyMode()
    }

    mutating func reset() {
        applyMode()
    }

    mutating func rotate(yaw: Float, pitch: Float) {
        goal.yaw += yaw
        goal.pitch = min(max(goal.pitch + pitch, Self.minPitch), Self.maxPitch)
        if mode == .top {
            mode = .overview
        }
    }

    mutating func zoom(_ steps: Float) {
        goal.distance = min(max(goal.distance * pow(0.88, steps), 0.32), 2.2)
    }

    /// The share of the window's width left for the board beside the panel: the view centers on it, and widens when
    /// it is narrow, so that the whole board stays in sight.
    mutating func setSpace(_ share: Float) {
        goal.shift = (share - 1) / 2
        goal.space = share
    }

    mutating func update(_ seconds: Float) {
        let ease = 1 - exp(-seconds * Self.ease)
        pose.target = pose.target + (goal.target - pose.target) * ease
        pose.yaw += (goal.yaw - pose.yaw) * ease
        pose.pitch += (goal.pitch - pose.pitch) * ease
        // The distance eases by ratio, so that zooming feels the same near and far.
        pose.distance *= pow(goal.distance / pose.distance, ease)
        pose.shift += (goal.shift - pose.shift) * ease
        pose.space += (goal.space - pose.space) * ease
    }

    var isMoving: Bool {
        length(goal.target - pose.target) > 1e-5 || abs(goal.yaw - pose.yaw) > 1e-4 || abs(goal.pitch - pose.pitch) > 1e-4
            || abs(goal.distance / pose.distance - 1) > 1e-4 || abs(goal.shift - pose.shift) > 1e-4 || abs(goal.space - pose.space) > 1e-4
    }

    var eye: SIMD3<Float> {
        let horizontal = cos(pose.pitch)
        return pose.target + SIMD3(sin(pose.yaw) * horizontal, sin(pose.pitch), cos(pose.yaw) * horizontal) * pose.distance
    }

    var view: float4x4 {
        // Looking straight down, "up" on the screen points away from the eye's side of the board.
        let yaw = pose.yaw
        let pitch = pose.pitch
        let up = Matrix.unit(SIMD3(-sin(yaw) * sin(pitch), cos(pitch), -cos(yaw) * sin(pitch)))
        return Matrix.lookAt(eye: eye, target: pose.target, up: up)
    }

    func projection(aspect: Float) -> float4x4 {
        let widen = max(1, Self.minAspect / (aspect * pose.space))
        var projection = Matrix.perspective(fovY: 2 * atan(tan(Self.fieldOfView / 2) * widen), aspect: aspect, near: 0.01, far: 20)
        projection.columns.2.x = -2 * pose.shift // a shift in normalized coordinates, which span 2
        return projection
    }

    /// The ray through a point of the window, in pixels from the top left.
    func ray(x: Float, y: Float, width: Float, height: Float) -> (origin: SIMD3<Float>, direction: SIMD3<Float>) {
        let inverse = (projection(aspect: width / max(height, 1)) * view).inverse
        let nx = x / width * 2 - 1
        let ny = 1 - y / height * 2
        let near = Matrix.transform(SIMD3(nx, ny, 0), by: inverse)
        let far = Matrix.transform(SIMD3(nx, ny, 1), by: inverse)
        return (near, Matrix.unit(far - near))
    }

    // MARK: - Helpers

    private mutating func applyMode() {
        goal.yaw = Self.unwrap(0, goal.yaw)
        switch mode {
        case .top:
            // Nearly straight down, tilted a little toward White so that the lamp is not mirrored in the whole board.
            goal.target = Self.middle
            goal.pitch = 1.3
            goal.distance = 1.0
        case .overview:
            goal.target = Self.middle + SIMD3(0, 0, 0.035)
            goal.pitch = Self.overviewPitch
            goal.distance = 0.92
        }
    }

    /// The angle nearest to `current` that points the same way as `angle`.
    private static func unwrap(_ angle: Float, _ current: Float) -> Float {
        var angle = angle
        while angle - current > Float.pi {
            angle -= 2 * Float.pi
        }
        while angle - current < -Float.pi {
            angle += 2 * Float.pi
        }
        return angle
    }
}
