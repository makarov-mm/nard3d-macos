/// Why the game cannot start, apart from the drawing.
enum GameError: Error, CustomStringConvertible {
    case damagedNetwork(String)

    var description: String {
        switch self {
        case .damagedNetwork(let name): "The computer player's network \(name) is missing from the program or damaged."
        }
    }
}
