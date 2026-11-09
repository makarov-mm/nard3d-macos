/// The two dice of a turn.
struct Roll: Equatable, Sendable {
    var first = 1
    var second = 1

    var isDouble: Bool { first == second }

    /// The dice in the order they are played: two, or four of a double.
    var dice: [Int] { isDouble ? [first, first, first, first] : [first, second] }
}
