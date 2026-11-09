/// One checker moved by the number of one die.
struct Step: Equatable, Sendable {
    /// A point, or `Nardy.fromBar`.
    var from: Int
    /// A point, or `Nardy.bearOff`.
    var to: Int
    var die: Int
    /// A lone checker of the opponent's is knocked to the bar.
    var hit = false
}
