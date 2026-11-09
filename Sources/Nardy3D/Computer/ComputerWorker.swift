import Foundation

/// Runs the computer's choice of move on a thread of its own; the game polls for the result.
final class ComputerWorker: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Move?
    private var stop: StopFlag?
    /// Each start and cancel moves it on, so that a late answer to an old question is dropped.
    private var generation = 0

    func start(net: Network, position: Position, variant: Variant, roll: Roll, firstMove: Bool, opponentFirst: Bool, level: Int,
               seed: UInt64) {
        let flag = StopFlag()
        lock.lock()
        stop?.raise()
        stop = flag
        result = nil
        generation += 1
        let ticket = generation
        lock.unlock()
        let thread = Thread { [weak self] in
            let move = ComputerPlayer.choose(net: net, position: position, variant: variant, roll: roll, firstMove: firstMove,
                                             opponentFirst: opponentFirst, level: level, seed: seed, stop: flag)
            self?.deliver(move, ticket: ticket)
        }
        thread.stackSize = 4 << 20
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    func cancel() {
        lock.lock()
        stop?.raise()
        stop = nil
        result = nil
        generation += 1
        lock.unlock()
    }

    /// The move, once it is chosen; each answer is given once.
    func take() -> Move? {
        lock.lock()
        defer { lock.unlock() }
        let move = result
        result = nil
        return move
    }

    private func deliver(_ move: Move, ticket: Int) {
        lock.lock()
        if ticket == generation {
            result = move
        }
        lock.unlock()
    }
}
