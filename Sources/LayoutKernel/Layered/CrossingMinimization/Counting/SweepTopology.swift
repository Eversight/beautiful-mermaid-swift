/// Flat, immutable adjacency for the crossing-counting hot loops.
///
/// The object walk (`port.connectedEdges` → `edge.source/target` → `LPort`)
/// pays ARC and exclusivity checks on every hop, every count, every sweep.
/// The connectivity never changes during sweeps — only positions do — so it
/// is built once per graph (dense `port.id`s are assigned by the counters'
/// init traversal) and the counting loops run on `Int32`s.
///
/// See `docs/SweepEngineDesign.md`, slice S1.
package struct SweepTopology {

    /// CSR row starts: port id → range into `adjacentPorts`. `portCount + 1` entries.
    package let adjacencyStart: [Int32]
    /// Other-end port ids of each port's non-self-loop edges, in
    /// `incoming ++ outgoing` order — the exact order the object walk used.
    package let adjacentPorts: [Int32]

    package var portCount: Int { adjacencyStart.count - 1 }

    /// Builds the adjacency from the traversed node order. Requires dense
    /// `port.id`s (0..<portCount), as assigned by `initAtPortLevel`.
    package init(nodeOrder: [[LNode]], portCount: Int) {
        guard portCount > 0 else {
            adjacencyStart = [0]
            adjacentPorts = []
            return
        }
        var degrees = [Int32](repeating: 0, count: portCount + 1)
        for layer in nodeOrder {
            for node in layer {
                for port in node.ports where port.id >= 0 && port.id < portCount {
                    var degree: Int32 = 0
                    for edge in port.connectedEdges where !(edge.source === edge.target) {
                        _ = edge
                        degree += 1
                    }
                    degrees[port.id + 1] = degree
                }
            }
        }

        var starts = degrees
        for i in 1...portCount {
            starts[i] += starts[i - 1]
        }
        adjacencyStart = starts

        var targets = [Int32](repeating: 0, count: Int(starts[portCount]))
        var cursor = starts
        for layer in nodeOrder {
            for node in layer {
                for port in node.ports where port.id >= 0 && port.id < portCount {
                    for edge in port.connectedEdges {
                        guard let source = edge.source, let target = edge.target,
                              !(source === target) else { continue }
                        let other = source === port ? target : source
                        guard other.id >= 0, other.id < portCount else { continue }
                        targets[Int(cursor[port.id])] = Int32(other.id)
                        cursor[port.id] += 1
                    }
                }
            }
        }
        adjacentPorts = targets
    }
}
