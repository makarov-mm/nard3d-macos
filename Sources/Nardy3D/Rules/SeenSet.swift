/// The keys met in one search, in a table of fixed size that is cleared at once by moving on to a new epoch.
struct SeenSet {
    private static let size = 1 << 14

    private var keys = [UInt64](repeating: 0, count: size)
    private var epochs = [UInt32](repeating: 0, count: size)
    private var epoch: UInt32 = 1

    mutating func clear() {
        epoch &+= 1
        if epoch == 0 {
            epochs = [UInt32](repeating: 0, count: Self.size)
            epoch = 1
        }
    }

    /// False when the key was already there. A crowded table lets keys through rather than look further.
    mutating func insert(_ key: UInt64) -> Bool {
        var slot = Int(truncatingIfNeeded: key ^ (key >> 29)) & (Self.size - 1)
        for _ in 0..<32 {
            if epochs[slot] != epoch {
                epochs[slot] = epoch
                keys[slot] = key
                return true
            }
            if keys[slot] == key {
                return false
            }
            slot = (slot + 1) & (Self.size - 1)
        }
        return true
    }
}
