/// The flat crossing-minimization engine (S2', docs/SweepEngineContract.md).
///
/// Owns the flat mutable sweep state over a `SweepGraph` and reproduces the
/// object engine's decisions bit-for-bit: same random draws in the same
/// order, same float accumulation orders, same tie behavior. Built up in
/// contract §8 steps; this file currently implements step 2 — barycenter
/// computation, unknown-barycenter fill-in, and the barycenter sort —
/// mirroring `BarycenterHeuristic` exactly (deviations are bugs, found by
/// the parity tests and the `SweepTrace` differential).
package struct SweepEngine {

    package let graph: SweepGraph
    /// The shared pipeline `Random` (dynamic dispatch — tests subclass it).
    /// Nil mirrors `BarycenterHeuristic`'s fallbacks (0.5 draws).
    package let random: Random?

    // MARK: Mutable sweep state (flat twins of the object-engine state)

    /// Per layer, flat node ids in current order.
    package var nodeOrder: [[Int32]]
    /// Global port permutation: node `n`'s current port order is
    /// `portOrder[nodePortStart[n]..<nodePortStart[n+1]]`. Starts as identity
    /// (initial port order == id order).
    package var portOrder: [Int32]
    /// Port id → rank (the distributor's live Float array).
    package var portRank: [Float]
    /// Port id → port barycenter (distributor scratch).
    package var portBarycenter: [Float]
    /// Node id → current position within its layer.
    package var nodePosition: [Int32]

    // BarycenterState, decomposed (node-indexed).
    package var barycenter: [Double]
    package var hasBarycenter: [Bool]
    package var summedWeight: [Double]
    package var degree: [Int32]
    package var visited: [Bool]

    /// Which rank calculator the engine mirrors — the object side picks
    /// NodeRelative (true) vs LayerTotal (false) with one `nextBoolean()` in
    /// `GraphInfoHolder.init`; the driver step consumes the same draw.
    package var useNodeRelativeRanks = true

    // Port-distribution scratch (the object distributor's instance fields).
    package var inLayerPortsScratch: [Int32] = []
    package var distMinBarycenter: Float = 0.0
    package var distMaxBarycenter: Float = 0.0

    // Flat counting state (S3): persistent positions (the object counter's
    // stale-history semantics) + reusable scratch and tree.
    package var flatPortPositions: [Int] = []
    package var countPortsScratch: [Int32] = []
    package var countEndsScratch: [Int] = []
    package var countStackScratch: [Int32] = []
    package var countTargetsScratch: [(Int32, Int)] = []
    package var countTree: BinaryIndexedTree?

    // Driver state (flat twins of graphsWhoseNodeOrderChanged + SweepCopy slots
    // + the firstTry/secondTry graph properties, which nothing else reads).
    package var orderChanged = false
    package var firstTryWithInitialOrder = false
    package var secondTryWithInitialOrder = false
    package var currentlyBestNodeOrder: [[Int32]]?
    package var currentlyBestPortOrder: [Int32]?
    package var bestNodeOrder: [[Int32]]?
    package var bestPortOrder: [Int32]?

    package init(graph: SweepGraph, random: Random?) {
        self.graph = graph
        self.random = random

        var order = [[Int32]](); order.reserveCapacity(graph.layerCount)
        for l in 0..<graph.layerCount {
            order.append(Array(graph.layerStart[l]..<graph.layerStart[l + 1]))
        }
        nodeOrder = order
        portOrder = Array(0..<Int32(graph.portCount))
        portRank = [Float](repeating: 0, count: graph.portCount)
        portBarycenter = [Float](repeating: 0, count: graph.portCount)
        var positions = [Int32](repeating: 0, count: graph.nodeCount)
        for l in 0..<graph.layerCount {
            let start = Int(graph.layerStart[l])
            for n in start..<Int(graph.layerStart[l + 1]) {
                positions[n] = Int32(n - start)
            }
        }
        nodePosition = positions
        barycenter = [Double](repeating: 0, count: graph.nodeCount)
        hasBarycenter = [Bool](repeating: false, count: graph.nodeCount)
        summedWeight = [Double](repeating: 0, count: graph.nodeCount)
        degree = [Int32](repeating: 0, count: graph.nodeCount)
        visited = [Bool](repeating: false, count: graph.nodeCount)
        flatPortPositions = [Int](repeating: 0, count: graph.portCount)
    }

    // MARK: - Barycenter computation (mirrors BarycenterHeuristic)

    /// `BarycenterHeuristic.randomizeBarycenters`: one `nextDouble()` per node
    /// in layer order.
    package mutating func randomizeBarycenters(_ layer: [Int32]) {
        for node in layer {
            let n = Int(node)
            let value = random?.nextDouble() ?? 0.5
            barycenter[n] = value
            hasBarycenter[n] = true
            summedWeight[n] = value
            degree[n] = 1
        }
    }

    /// `BarycenterHeuristic.calculateBarycenters`: reset visited for the
    /// layer, then a post-order DFS per node (in-layer neighbors first).
    package mutating func calculateBarycenters(_ layer: [Int32], forward: Bool) {
        for node in layer { visited[Int(node)] = false }
        for node in layer { calculateBarycenter(node, forward: forward) }
    }

    package mutating func calculateBarycenter(_ node: Int32, forward: Bool) {
        let n = Int(node)
        if visited[n] { return }
        visited[n] = true
        degree[n] = 0
        summedWeight[n] = 0.0
        barycenter[n] = 0.0
        hasBarycenter[n] = false

        let myLayer = graph.nodeLayer[n]

        // Ports in CURRENT order (the object walk iterates node.getPorts(),
        // which the distributor mutates; float accumulation order follows it).
        for pi in Int(graph.nodePortStart[n])..<Int(graph.nodePortStart[n + 1]) {
            let port = Int(portOrder[pi])
            // forward → predecessor ports (incoming slice); backward →
            // successor ports (outgoing slice). Order within each slice is
            // edge-list order — `getPredecessorPorts`/`getSuccessorPorts`.
            let rowStart = Int(graph.adjStart[port])
            let rowEnd = Int(graph.adjStart[port + 1])
            let incomingEnd = rowStart + Int(graph.adjIncomingCount[port])
            let slice = forward ? rowStart..<incomingEnd : incomingEnd..<rowEnd
            for i in slice {
                let farPort = Int(graph.adjFarPort[i])
                let farNode = graph.portNode[farPort]
                if graph.nodeLayer[Int(farNode)] == myLayer {
                    if farNode != node {
                        calculateBarycenter(farNode, forward: forward)
                        degree[n] += degree[Int(farNode)]
                        summedWeight[n] += summedWeight[Int(farNode)]
                    }
                } else {
                    summedWeight[n] += Double(portRank[farPort])
                    degree[n] += 1
                }
            }
        }

        // BARYCENTER_ASSOCIATES, property order, same-layer only.
        for i in Int(graph.associatesStart[n])..<Int(graph.associatesStart[n + 1]) {
            let associate = graph.associates[i]
            guard graph.nodeLayer[Int(associate)] == myLayer else { continue }
            calculateBarycenter(associate, forward: forward)
            degree[n] += degree[Int(associate)]
            summedWeight[n] += summedWeight[Int(associate)]
        }

        if degree[n] > 0 {
            // Exact float shape of BH:177-182: Float draw, Float constant,
            // Float halving, each widened to Double before the arithmetic.
            let rf = random?.nextFloat() ?? 0.5
            summedWeight[n] += Double(rf) * Double(BarycenterHeuristic.RANDOM_AMOUNT)
                - Double(BarycenterHeuristic.RANDOM_AMOUNT / 2)
            barycenter[n] = summedWeight[n] / Double(degree[n])
            hasBarycenter[n] = true
        }
    }

    /// `BarycenterHeuristic.fillInUnknownBarycenters`.
    package mutating func fillInUnknownBarycenters(_ layer: [Int32], preOrdered: Bool) {
        if preOrdered {
            var lastValue: Double = -1
            var i = 0
            while i < layer.count {
                let n = Int(layer[i])
                var value: Double? = hasBarycenter[n] ? barycenter[n] : nil
                if value == nil {
                    var nextValue = lastValue + 1
                    var j = i + 1
                    while j < layer.count {
                        let m = Int(layer[j])
                        if hasBarycenter[m] {
                            nextValue = barycenter[m]
                            break
                        }
                        j += 1
                    }

                    let v = (lastValue + nextValue) / 2
                    value = v
                    barycenter[n] = v
                    hasBarycenter[n] = true
                    summedWeight[n] = v
                    degree[n] = 1
                }
                lastValue = value ?? lastValue
                i += 1
            }
        } else {
            var maxBary: Double = 0
            for node in layer {
                let n = Int(node)
                if hasBarycenter[n] {
                    maxBary = Swift.max(maxBary, barycenter[n])
                }
            }
            maxBary += 2
            for node in layer {
                let n = Int(node)
                if !hasBarycenter[n] {
                    let rf = random?.nextFloat() ?? 0.5
                    let value = Double(rf) * maxBary - 1
                    barycenter[n] = value
                    hasBarycenter[n] = true
                    summedWeight[n] = value
                    degree[n] = 1
                }
            }
        }
    }

    /// `BarycenterHeuristic.sortByBarycenter` (#15's snapshot sort): same key
    /// sequence, same predicate, same stdlib sort ⇒ same permutation. The
    /// payload type (Int32 vs LNode) cannot affect a comparison sort.
    package mutating func sortByBarycenter(_ layer: inout [Int32]) {
        var keyed = [(barycenter: Double?, node: Int32)]()
        keyed.reserveCapacity(layer.count)
        for node in layer {
            let n = Int(node)
            keyed.append((hasBarycenter[n] ? barycenter[n] : nil, node))
        }
        keyed.sort { lhs, rhs in
            guard let l = lhs.barycenter else { return false }
            guard let r = rhs.barycenter else { return true }
            return l < r
        }
        for i in layer.indices {
            layer[i] = keyed[i].node
        }
    }
}
