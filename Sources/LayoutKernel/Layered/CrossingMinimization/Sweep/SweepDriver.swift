/// S2' step 5: the flat driver loop — `compareDifferentRandomizedLayouts` →
/// `minimizeCrossingsWithCounter` for the v1 subset (contract §4), with
/// crossing counts DELEGATED to the object `AllCrossingsCounter` via O(V+P)
/// write-back (contract §2: hyperedge tie-breaks are address-dependent and
/// `portPositions` carries observable stale history — the same counter object
/// must run the same call sequence).
///
/// Snapshots are two flat array copies instead of `SweepCopy` object graphs —
/// the profiled `SweepCopy.init` hot leaf disappears.
///
/// Trace events mirror the object driver's hooks exactly (same values: node
/// ids are per-layer initial positions, port ids are global), so
/// `SweepTrace.firstDivergence` pinpoints the first divergent decision
/// between engines.
extension SweepEngine {

    /// The mirror of `LayerSweepCrossingMinimizer.compareDifferentRandomizedLayouts`
    /// for plain-barycenter configs (influences == 0 — the Int-valued loop).
    /// `modelOrderStrategy != .NONE` (Mermaid sets NODES_AND_EDGES) activates
    /// the firstTry/secondTry rotation: try 1 keeps the initial order and
    /// sweeps forward, try 2 backward, later tries randomize. The object code
    /// carries the flags as graph properties; nothing outside the driver
    /// reads them, so they live as locals here.
    /// `randomSeed` is the driver's post-`nextLong` value.
    package mutating func compareDifferentRandomizedLayouts(
        holder: GraphInfoHolder, randomSeed: Int, thoroughness: Int = 7,
        modelOrderStrategyActive: Bool = false
    ) {
        random?.setSeed(randomSeed)
        orderChanged = false
        currentlyBestNodeOrder = nil
        currentlyBestPortOrder = nil
        bestNodeOrder = nil
        bestPortOrder = nil
        firstTryWithInitialOrder = modelOrderStrategyActive
        secondTryWithInitialOrder = false

        var bestCrossings = Int.max
        for _ in 0..<Swift.max(1, thoroughness) {
            let crossings = minimizeCrossingsWithCounter(holder: holder)
            if crossings < bestCrossings {
                bestCrossings = crossings
                saveBestOrders()
                if bestCrossings == 0 {
                    break
                }
            }
        }
    }

    /// One try. Returns the crossing count of the best state seen (the count
    /// BEFORE the failed improving sweep).
    package mutating func minimizeCrossingsWithCounter(holder: GraphInfoHolder) -> Int {
        var isForwardSweep = random?.nextBoolean() ?? true
        LayerSweepCrossingMinimizer.trace?.record(.tryStart(forward: isForwardSweep))
        let initialCrossings = countCrossings(holder: holder)
        if initialCrossings == 0, firstTryWithInitialOrder {
            return 0
        }

        if !(firstTryWithInitialOrder || secondTryWithInitialOrder) {
            setFirstLayerOrder(forward: isForwardSweep)
        } else {
            isForwardSweep = firstTryWithInitialOrder
        }
        sweepReducingCrossings(forward: isForwardSweep, firstSweep: true)

        if secondTryWithInitialOrder {
            secondTryWithInitialOrder = false
        }
        if firstTryWithInitialOrder {
            firstTryWithInitialOrder = false
            secondTryWithInitialOrder = true
        }

        var crossingsInGraph = countCrossings(holder: holder)
        var oldCrossings: Int
        repeat {
            setCurrentlyBestNodeOrders()
            if crossingsInGraph == 0 {
                return 0
            }
            isForwardSweep.toggle()
            oldCrossings = crossingsInGraph
            sweepReducingCrossings(forward: isForwardSweep, firstSweep: false)
            crossingsInGraph = countCrossings(holder: holder)
        } while oldCrossings > crossingsInGraph

        return oldCrossings
    }

    // MARK: Sweeping

    /// `sweepReducingCrossings`. The hierarchical-node scan is omitted: the
    /// dispatch predicate guarantees no nested graphs, and the scan is pure
    /// reads (no draws) when empty.
    package mutating func sweepReducingCrossings(forward: Bool, firstSweep: Bool) {
        let length = nodeOrder.count
        guard length > 0 else { return }

        distributePortsWhileSweeping(firstIndex(forward, length), forward: forward)

        // The object driver re-reads the flags per free layer; they are
        // constant for the duration of one sweep (mutations happen between
        // sweeps), so hoisting is behavior-identical.
        let isRandomizingSweep = firstSweep
            && !firstTryWithInitialOrder && !secondTryWithInitialOrder

        var i = forward ? 1 : length - 2
        while forward ? i < length : i >= 0 {
            crossMinimizeLayer(i, forward: forward, isFirstSweep: isRandomizingSweep)
            distributePortsWhileSweeping(i, forward: forward)
            i += forward ? 1 : -1
        }

        orderChanged = true
    }

    /// `BarycenterHeuristic.minimizeCrossings(order:freeLayerIndex:forward:isFirstSweep:)`
    /// via the driver's `crossMinimize`.
    package mutating func crossMinimizeLayer(_ index: Int, forward: Bool, isFirstSweep: Bool) {
        guard index >= 0, index < nodeOrder.count, !nodeOrder[index].isEmpty else { return }

        if index != firstIndex(forward, nodeOrder.count) {
            calculatePortRanks(layerIndex: index - (forward ? 1 : -1), output: forward)
        }

        let firstNode = Int(nodeOrder[index][0])
        let preOrdered = !isFirstSweep || graph.isExternalPortDummy[firstNode]

        var layer = nodeOrder[index]
        calculateBarycenters(layer, forward: forward)
        fillInUnknownBarycenters(layer, preOrdered: preOrdered)
        if layer.count > 1 {
            sortByBarycenter(&layer)
            processConstraints(&layer)
        }
        nodeOrder[index] = layer
        recordLayerOrder(index)
    }

    /// `setFirstLayerOrder` (the randomize path).
    package mutating func setFirstLayerOrder(forward: Bool) {
        guard !nodeOrder.isEmpty else { return }
        let start = firstIndex(forward, nodeOrder.count)

        var layer = nodeOrder[start]
        randomizeBarycenters(layer)
        if layer.count > 1 {
            sortByBarycenter(&layer)
            processConstraints(&layer)
        }
        nodeOrder[start] = layer
        recordLayerOrder(start)
    }

    private func firstIndex(_ forward: Bool, _ length: Int) -> Int {
        forward ? 0 : length - 1
    }

    // MARK: Counting (write-back delegation)

    /// Counts crossings: fully flat when the graph has no hyperedge
    /// boundaries (S3 — zero write-back, zero object walks); otherwise
    /// write-back + the object counters (their hyperedge tie-breaks are
    /// address-dependent and irreproducible, contract §2).
    package mutating func countCrossings(holder: GraphInfoHolder) -> Int {
        let crossings: Int
        if graph.usesObjectCounting {
            writeBackPortOrders()
            let objectOrder = nodeOrder.map { layer in
                layer.map { graph.objectNodes[Int($0)] }
            }
            crossings = holder.crossCounter().countAllCrossings(objectOrder)
        } else {
            crossings = flatCountAllCrossings()
        }
        LayerSweepCrossingMinimizer.trace?.record(.count(crossings: crossings))
        return crossings
    }

    /// Applies the flat port permutation to `node.ports` for nodes whose
    /// order can have changed (fixed nodes are never resorted).
    package mutating func writeBackPortOrders() {
        for n in 0..<graph.nodeCount where !graph.portConstraintsFixed[n] {
            let range = Int(graph.nodePortStart[n])..<Int(graph.nodePortStart[n + 1])
            guard !range.isEmpty else { continue }
            graph.objectNodes[n].ports = range.map { graph.objectPorts[Int(portOrder[$0])] }
        }
    }

    // MARK: Snapshots (flat SweepCopy)

    package mutating func setCurrentlyBestNodeOrders() {
        LayerSweepCrossingMinimizer.trace?.record(.snapshotBest)
        guard orderChanged else { return }
        currentlyBestNodeOrder = nodeOrder
        currentlyBestPortOrder = portOrder
    }

    package mutating func saveBestOrders() {
        LayerSweepCrossingMinimizer.trace?.record(.saveBest)
        guard orderChanged else { return }
        bestNodeOrder = currentlyBestNodeOrder ?? nodeOrder
        bestPortOrder = currentlyBestPortOrder ?? portOrder
    }

    // MARK: Transfer

    /// Materializes the best flat snapshot into the object graph and runs the
    /// object `SweepCopy` transfer (once per layout; its mutation mechanics —
    /// detach/reattach, FIXED_ORDER stamping, N/S re-sort, cache refresh —
    /// stay authoritative).
    ///
    /// No snapshot ⇒ no transfer: when the firstTry early-out returns 0
    /// crossings before any sweep, the object driver's `getBestSweep()` is
    /// nil and it leaves the graph completely untouched — transferring the
    /// (identical) current order would still stamp FIXED_ORDER and rewrite
    /// ids, a property-state divergence the object path never performs.
    package mutating func transferBestOrders(to lGraph: LGraph) {
        guard let nodeSnapshot = bestNodeOrder, let portSnapshot = bestPortOrder else {
            return
        }

        let savedPortOrder = portOrder
        portOrder = portSnapshot
        writeBackPortOrders()
        portOrder = savedPortOrder

        let objectOrder = nodeSnapshot.map { layer in
            layer.map { graph.objectNodes[Int($0)] }
        }
        SweepCopy(objectOrder).transferNodeAndPortOrdersToGraph(lGraph, true)
    }

    // MARK: Trace

    /// Object trace events carry `node.id` (the initial per-layer position);
    /// flat global ids convert by subtracting the layer base.
    private func recordLayerOrder(_ index: Int) {
        guard let trace = LayerSweepCrossingMinimizer.trace else { return }
        let ids = nodeOrder[index].map { flatId -> Int in
            let layer = Int(graph.nodeLayer[Int(flatId)])
            return Int(flatId - graph.layerStart[layer])
        }
        trace.record(.layerOrder(layer: index, nodeIds: ids))
    }
}
