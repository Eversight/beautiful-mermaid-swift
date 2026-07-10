/// Differential trace for the S2' sweep-engine parity harness.
///
/// Both the object engine (`LayerSweepCrossingMinimizer`) and the flat engine
/// record the same decision points when a trace is installed. The parity test
/// runs one full layout per engine (layout is deterministic for a fixed seed,
/// so separate runs see identical inputs) and diffs the two event streams —
/// the first divergent event pinpoints the first divergent decision, which is
/// vastly more debuggable than a byte-diff of final positions.
///
/// Tracing is test-harness-only: `LayerSweepCrossingMinimizer.trace` is nil in
/// production, costing one nil-check per recording site. The trace is not
/// thread-safe; parity tests run layouts sequentially on one thread.
package final class SweepTrace {

    package enum Event: Equatable, CustomStringConvertible {
        /// A minimization try began; `forward` is the initial sweep direction
        /// (consumes one `random.nextBoolean()`).
        case tryStart(forward: Bool)
        /// A layer's node order after `crossMinimize` ran on it.
        case layerOrder(layer: Int, nodeIds: [Int])
        /// A node's port order after `sortPorts` reordered it.
        case portOrder(node: Int, portIds: [Int])
        /// A crossing count taken at a sweep boundary.
        case count(crossings: Int)
        /// `setCurrentlyBestNodeOrders` snapshotted the current order.
        case snapshotBest
        /// `saveAllNodeOrdersOfChangedGraphs` accepted a new best try.
        case saveBest

        package var description: String {
            switch self {
            case .tryStart(let forward): return "tryStart(forward: \(forward))"
            case .layerOrder(let layer, let ids): return "layerOrder(\(layer): \(ids))"
            case .portOrder(let node, let ids): return "portOrder(\(node): \(ids))"
            case .count(let crossings): return "count(\(crossings))"
            case .snapshotBest: return "snapshotBest"
            case .saveBest: return "saveBest"
            }
        }
    }

    package private(set) var events: [Event] = []

    package init() {}

    @inline(__always)
    package func record(_ event: Event) {
        events.append(event)
    }

    /// Index of the first event where the two traces differ, or nil if one is
    /// a prefix of the other (compare counts separately for full equality).
    package static func firstDivergence(_ a: SweepTrace, _ b: SweepTrace) -> Int? {
        for i in 0..<Swift.min(a.events.count, b.events.count) where a.events[i] != b.events[i] {
            return i
        }
        return nil
    }
}
