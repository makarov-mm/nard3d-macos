/// A whole turn: up to four steps, and the position they leave, still from the mover's side.
struct Move: Sendable {
    var steps: [Step] = []
    var after = Position()

    var count: Int { steps.count }
}
