import Foundation

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p3order/BarycenterHeuristic.java
package class BarycenterHeuristic:
    ICrossingMinimizationHeuristic,
    IInitializable
{
    package static let FORCE_MODEL_ORDER_KEY = "org.eclipse.elk.layered.crossingMinimization.forceNodeModelOrder"
    package static let RANDOM_AMOUNT: Float = 0.07

    package var portRanks: [Float] = []
    package var random: Random?
    package var constraintResolver: ForsterConstraintResolver?
    package var barycenterState: [[BarycenterState?]] = []
    package var portDistributor: AbstractBarycenterPortDistributor?

    package init() {}

    package init(
        _ constraintResolver: ForsterConstraintResolver,
        _ random: Any? = nil,
        _ portDistributor: AbstractBarycenterPortDistributor,
        _ graph: [[LNode]]
    ) {
        self.constraintResolver = constraintResolver
        self.portDistributor = portDistributor
        self.random = random as? Random
        _ = graph
    }

    package func minimizeCrossings(
        _ layer: inout [LNode],
        _ preOrdered: Bool,
        _ randomize: Bool,
        _ forward: Bool
    ) {
        if randomize {
            randomizeBarycenters(layer)
        } else {
            calculateBarycenters(layer, forward)
            fillInUnknownBarycenters(layer, preOrdered)
        }

        if layer.count > 1 {
            // Model-order-specific sorting lives in ModelOrderBarycenterHeuristic,
            // which overrides this method entirely; the base heuristic always
            // sorts by barycenter. (The old force-model-order branch here was a
            // dead read: both arms were identical.)
            sortByBarycenter(&layer)

            constraintResolver?.processConstraints(&layer)
        }
    }

    package func minimizeCrossings(
        _ layer: [LNode],
        _ preOrdered: Bool,
        _ randomize: Bool,
        _ forward: Bool
    ) {
        var mutableLayer = layer
        minimizeCrossings(&mutableLayer, preOrdered, randomize, forward)
    }

    package func randomizeBarycenters(_ nodes: [LNode]) {
        for node in nodes {
            let state = stateOf(node)
            state.barycenter = nextDouble()
            state.summedWeight = state.barycenter ?? 0.0
            state.degree = 1
        }
    }

    package func fillInUnknownBarycenters(
        _ nodes: [LNode],
        _ preOrdered: Bool
    ) {
        if preOrdered {
            var lastValue: Double = -1
            var i = 0
            while i < nodes.count {
                let node = nodes[i]
                let state = stateOf(node)
                var value = state.barycenter
                if value == nil {
                    var nextValue = lastValue + 1
                    var j = i + 1
                    while j < nodes.count {
                        if let x = stateOf(nodes[j]).barycenter {
                            nextValue = x
                            break
                        }
                        j += 1
                    }

                    value = (lastValue + nextValue) / 2
                    state.barycenter = value
                    state.summedWeight = value ?? 0.0
                    state.degree = 1
                }

                lastValue = value ?? lastValue
                i += 1
            }
        } else {
            var maxBary: Double = 0
            for node in nodes {
                if let bary = stateOf(node).barycenter {
                    maxBary = Swift.max(maxBary, bary)
                }
            }

            maxBary += 2
            for node in nodes {
                let state = stateOf(node)
                if state.barycenter == nil {
                    let value = Double(nextFloat()) * maxBary - 1
                    state.barycenter = value
                    state.summedWeight = value
                    state.degree = 1
                }
            }
        }
    }

    package func calculateBarycenters(
        _ nodes: [LNode],
        _ forward: Bool
    ) {
        for node in nodes {
            stateOf(node).visited = false
        }
        for node in nodes {
            calculateBarycenter(node, forward)
        }
    }

    package func calculateBarycenter(_ node: LNode, _ forward: Bool) {
        let nodeState = stateOf(node)
        if nodeState.visited {
            return
        }
        nodeState.visited = true
        nodeState.degree = 0
        nodeState.summedWeight = 0.0
        nodeState.barycenter = nil

        for freePort in node.getPorts() {
            let portIterable = forward ? freePort.getPredecessorPorts() : freePort.getSuccessorPorts()
            for fixedPort in portIterable {
                guard let fixedNode = fixedPort.getNode() else { continue }
                if fixedNode.getLayer() === node.getLayer() {
                    if fixedNode !== node {
                        calculateBarycenter(fixedNode, forward)
                        let fixedState = stateOf(fixedNode)
                        nodeState.degree += fixedState.degree
                        nodeState.summedWeight += fixedState.summedWeight
                    }
                } else {
                    nodeState.summedWeight += rankOfPort(fixedPort)
                    nodeState.degree += 1
                }
            }
        }

        let associatesKey = InternalProperties.BARYCENTER_ASSOCIATES
        let barycenterAssociates: [LNode]? = node.getProperty(associatesKey)
        if let barycenterAssociates {
            for associate in barycenterAssociates where node.getLayer() === associate.getLayer() {
                calculateBarycenter(associate, forward)
                let associateState = stateOf(associate)
                nodeState.degree += associateState.degree
                nodeState.summedWeight += associateState.summedWeight
            }
        }

        if nodeState.degree > 0 {
            let rf = nextFloat()
            nodeState.summedWeight +=
                Double(rf) * Double(Self.RANDOM_AMOUNT) - Double(Self.RANDOM_AMOUNT / 2)
            nodeState.barycenter = nodeState.summedWeight / Double(nodeState.degree)
        }
    }

    package func stateOf(_ node: LNode) -> BarycenterState {
        let layerId = max(0, node.getLayer()?.id ?? 0)
        let nodeId = max(0, node.id)

        ensureBarycenterStateCapacity(layerId: layerId, nodeId: nodeId)
        if let existing = barycenterState[layerId][nodeId] {
            return existing
        }
        let created = BarycenterState(node)
        barycenterState[layerId][nodeId] = created
        return created
    }

    /// Sorts a layer ascending by barycenter, nodes without a barycenter last,
    /// ties keeping their previous relative outcome — the exact semantics of the
    /// Java `barycenterStateComparator`. Each node's barycenter is resolved
    /// **once** into a local snapshot; the previous closure-based sort re-resolved
    /// both nodes' states on every comparison (an exclusivity-checked 2D-array
    /// lookup each, O(n log n) of them). The snapshot predicate returns the same
    /// boolean for every pair the old comparator did (it is a pure function of
    /// barycenter values, which do not change during the sort), so the resulting
    /// permutation is identical.
    package func sortByBarycenter(_ layer: inout [LNode]) {
        var keyed = [(barycenter: Double?, node: LNode)]()
        keyed.reserveCapacity(layer.count)
        for node in layer {
            keyed.append((stateOf(node).barycenter, node))
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

    package func minimizeCrossings(
        _ order: inout [[LNode]],
        _ freeLayerIndex: Int,
        _ forwardSweep: Bool,
        _ isFirstSweep: Bool
    ) -> Bool {
        guard freeLayerIndex >= 0, freeLayerIndex < order.count, !order[freeLayerIndex].isEmpty else {
            return false
        }

        if !isFirstLayer(order, freeLayerIndex, forwardSweep) {
            let fixedLayer = order[freeLayerIndex - changeIndex(forwardSweep)]
            portDistributor?.calculatePortRanks(fixedLayer, portTypeFor(forwardSweep))
        }

        let firstNodeInLayer = order[freeLayerIndex][0]
        let preOrdered = !isFirstSweep || isExternalPortDummy(firstNodeInLayer)

        var nodes = Array(order[freeLayerIndex])
        minimizeCrossings(&nodes, preOrdered, false, forwardSweep)
        order[freeLayerIndex] = nodes
        return false
    }

    package func setFirstLayerOrder(_ order: inout [[LNode]], _ isForwardSweep: Bool) -> Bool {
        guard !order.isEmpty else { return false }
        let startIndex = startIndex(isForwardSweep, order.count)
        guard startIndex >= 0, startIndex < order.count else { return false }

        var nodes = Array(order[startIndex])
        minimizeCrossings(&nodes, false, true, isForwardSweep)
        order[startIndex] = nodes
        return false
    }

    package func isExternalPortDummy(_ firstNode: LNode) -> Bool {
        firstNode.getType() == .EXTERNAL_PORT
    }

    package func changeIndex(_ dir: Bool) -> Int {
        dir ? 1 : -1
    }

    package func portTypeFor(_ direction: Bool) -> PortType {
        direction ? .OUTPUT : .INPUT
    }

    package func startIndex(_ dir: Bool, _ length: Int) -> Int {
        dir ? 0 : max(0, length - 1)
    }

    package func isFirstLayer(
        _ nodeOrder: [[LNode]],
        _ currentIndex: Int,
        _ forwardSweep: Bool
    ) -> Bool {
        currentIndex == startIndex(forwardSweep, nodeOrder.count)
    }

    package func alwaysImproves() -> Bool {
        false
    }

    package func isDeterministic() -> Bool {
        false
    }

    package func initAfterTraversal() {
        barycenterState = constraintResolver?.getBarycenterStates() ?? []
        if let distributor = portDistributor {
            portRanks = distributor.getPortRanks()
        } else {
            portRanks = []
        }
    }

    package func initAtLayerLevel(_ l: Int, _ nodeOrder: [[LNode]]) {
        guard l >= 0, l < nodeOrder.count, let first = nodeOrder[l].first, let layer = first.getLayer() else {
            return
        }
        layer.id = l
        let maxNodeId = nodeOrder[l].map(\.id).max() ?? -1
        if maxNodeId >= 0 {
            ensureBarycenterStateCapacity(layerId: l, nodeId: maxNodeId)
        }
    }

    package func ensureBarycenterStateCapacity(layerId: Int, nodeId: Int) {
        if barycenterState.count <= layerId {
            barycenterState += Array(repeating: [], count: layerId - barycenterState.count + 1)
        }
        if barycenterState[layerId].count <= nodeId {
            barycenterState[layerId] += Array(repeating: nil, count: nodeId - barycenterState[layerId].count + 1)
        }
    }

    package func rankOfPort(_ port: LPort) -> Double {
        // Read directly from the distributor's portRanks array, not from our copy.
        // In Java, getPortRanks() returns a reference to the same float[] array,
        // so updates by calculatePortRanks during sweeps are visible. In Swift,
        // arrays are value types so we must read from the source.
        let id = port.id
        if let distributor = portDistributor {
            let ranks = distributor.getPortRanks()
            guard id >= 0, id < ranks.count else { return 0.0 }
            return Double(ranks[id])
        }
        guard id >= 0, id < portRanks.count else { return 0.0 }
        return Double(portRanks[id])
    }

    package func nextDouble() -> Double {
        return random?.nextDouble() ?? 0.5
    }

    package func nextFloat() -> Float {
        return random?.nextFloat() ?? 0.5
    }
}
