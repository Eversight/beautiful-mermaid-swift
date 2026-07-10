/// Flat, typed representation of everything the crossing-minimization sweep
/// reads — the S2' engine's world (docs/SweepEngineContract.md §3).
///
/// Built once per `process()` after `GraphInfoHolder.initializeByTraversal`
/// has assigned dense ids (`layer.id` = layer index, `node.id` = initial
/// position in layer, `port.id` = global visit index in layers→nodes→ports
/// order). Because ports are visited per node, port ids are contiguous per
/// node: node `n`'s ports are exactly `nodePortStart[n]..<nodePortStart[n+1]`,
/// and the initial port order is id order.
///
/// The adjacency keeps BOTH kinds of self-loops (port-level and node-level)
/// and omits only dangling edges (nil endpoint): the barycenter walk skips
/// same-node far ends itself, while the port distributor's in-layer detection
/// genuinely fires on self-loops — omitting them would diverge (contract §3).
/// Dangling edges are safe to omit everywhere but still count in `portDegree`
/// (the barycenter denominator uses `getDegree()`, which includes them).
///
/// Building is a pure read: no property writes, no id writes, no Random draws.
package struct SweepGraph {

    // MARK: Layer / node / port structure

    package let layerCount: Int
    package let nodeCount: Int
    package let portCount: Int

    /// Layer → flat node id range: `layerStart[l]..<layerStart[l+1]`.
    /// Flat node id = `layerStart[layer.id] + node.id` (initial position).
    package let layerStart: [Int32]
    /// Flat node id → its layer index.
    package let nodeLayer: [Int32]
    /// Flat node id → its port id range (`nodePortStart[n]..<nodePortStart[n+1]`).
    package let nodePortStart: [Int32]
    /// Port id → owning flat node id.
    package let portNode: [Int32]
    /// Port id → side ordinal (UNDEFINED 0, NORTH 1, EAST 2, SOUTH 3, WEST 4 —
    /// the `sortPorts` ordering, AbstractBarycenterPortDistributor.sideOrdinal).
    package let portSide: [UInt8]
    /// Port id → `getDegree()` (incoming + outgoing edge counts, INCLUDING
    /// dangling edges that the adjacency omits).
    package let portDegree: [Int32]
    /// Port id → raw `incomingEdges.count` (including dangling). The
    /// `getPorts(.INPUT)` filter and the rank calculators' input counts test
    /// raw edge-list emptiness, not adjacency rows.
    package let portIncomingCount: [Int32]

    // MARK: Adjacency (CSR)

    /// Port id → row range into `adjFarPort`.
    package let adjStart: [Int32]
    /// First `adjIncomingCount[p]` entries of row `p` are incoming (far end =
    /// edge source, in `incomingEdges` order); the rest are outgoing (far end
    /// = edge target, in `outgoingEdges` order) — `getConnectedEdges()` order.
    package let adjIncomingCount: [Int32]
    package let adjFarPort: [Int32]

    // MARK: Typed attribute slots (populated once from the property maps)

    /// Node → `PortConstraints.isOrderFixed()` ("org.eclipse.elk.portConstraints").
    package let portConstraintsFixed: [Bool]
    /// Node → `getType() == .NORMAL` (Forster's layout-unit chaining).
    package let isNormalNode: [Bool]
    /// Node → `getType() == .EXTERNAL_PORT` (preOrdered check on first layers).
    package let isExternalPortDummy: [Bool]
    /// Node → `getType() == .LONG_EDGE` (north-south counting walks).
    package let isLongEdgeNode: [Bool]
    /// Node → `getType() == .NORTH_SOUTH_PORT`.
    package let isNorthSouthDummy: [Bool]
    /// Node → its `IN_LAYER_LAYOUT_UNIT` representative as flat id, -1 if the
    /// property is absent (the reverse of `unitMembers`).
    package let layoutUnitOf: [Int32]

    // MARK: Counting flags (AllCrossingsCounter's init-time routing, static)

    /// Layer → contains a NORTH_SOUTH_PORT dummy.
    package let layerHasNorthSouthPorts: [Bool]
    /// Layer boundary l→l+1 → routed to the hyperedge counter (a port with
    /// >1 edges on EAST at layer l, or WEST at layer l+1 — ACC init rule).
    package let hasHyperEdgesEastOfIndex: [Bool]
    /// Any hyperedge boundary anywhere: counting must stay on the object
    /// counters wholesale (their tie-breaks are address-dependent and the
    /// stale portPositions history must not be split across engines).
    package let usesObjectCounting: Bool

    /// Node → `BARYCENTER_ASSOCIATES` as flat node ids, property array order.
    package let associatesStart: [Int32]
    package let associates: [Int32]
    /// Node → `IN_LAYER_SUCCESSOR_CONSTRAINTS` as flat node ids.
    package let inLayerSuccessorsStart: [Int32]
    package let inLayerSuccessors: [Int32]
    /// Node → members of the layout unit this node REPRESENTS (nodes whose
    /// `IN_LAYER_LAYOUT_UNIT` property points at it), in traversal append
    /// order — Forster's `layoutUnits` dictionary, flattened. Empty range ⇒
    /// `layoutUnitNodes(for:)` falls back to `[node]`.
    package let unitMembersStart: [Int32]
    package let unitMembers: [Int32]

    /// Port id → north/south "portDummy" property as flat node id, -1 if none.
    package let nsPortDummyNode: [Int32]
    /// Port id → "origin" property (on dummy-node ports) as port id, -1 if none.
    package let dummyPortOrigin: [Int32]

    // MARK: Object bridge (write-back for counting and final transfer)

    /// Flat node id → the object node.
    package let objectNodes: [LNode]
    /// Port id → the object port.
    package let objectPorts: [LPort]

    // MARK: - Build

    /// Builds from the traversed node order. Traps (in debug) if the dense-id
    /// preconditions do not hold — the dispatch predicate must only route
    /// graphs here after `GraphInfoHolder.initializeByTraversal`.
    package init(nodeOrder: [[LNode]]) {
        let layerCount = nodeOrder.count
        var layerStart = [Int32](); layerStart.reserveCapacity(layerCount + 1)
        layerStart.append(0)

        var objectNodes: [LNode] = []
        var objectPorts: [LPort] = []
        var nodeLayer: [Int32] = []
        var nodePortStart: [Int32] = [0]
        var portNode: [Int32] = []
        var portSide: [UInt8] = []
        var portDegree: [Int32] = []
        var portIncomingCount: [Int32] = []

        var nodeIds = [ObjectIdentifier: Int32]()
        for (l, layer) in nodeOrder.enumerated() {
            for (n, node) in layer.enumerated() {
                assert(node.id == n, "node.id must be the initial layer position")
                assert(node.getLayer()?.id == l, "layer.id must be the layer index")
                nodeIds[ObjectIdentifier(node)] = Int32(objectNodes.count)
                objectNodes.append(node)
                nodeLayer.append(Int32(l))
                for port in node.getPorts() {
                    assert(port.id == objectPorts.count, "port.id must be the global visit index")
                    objectPorts.append(port)
                    portNode.append(Int32(objectNodes.count - 1))
                    portSide.append(Self.sideOrdinal(port.getSide()))
                    portDegree.append(Int32(port.getDegree()))
                    portIncomingCount.append(Int32(port.getIncomingEdges().count))
                }
                nodePortStart.append(Int32(objectPorts.count))
            }
            layerStart.append(Int32(objectNodes.count))
        }
        let nodeCount = objectNodes.count
        let portCount = objectPorts.count

        // Adjacency: incoming then outgoing, dangling omitted, self-loops kept.
        var adjStart = [Int32](); adjStart.reserveCapacity(portCount + 1)
        adjStart.append(0)
        var adjIncomingCount = [Int32](); adjIncomingCount.reserveCapacity(portCount)
        var adjFarPort: [Int32] = []
        for port in objectPorts {
            var incoming: Int32 = 0
            for edge in port.getIncomingEdges() {
                guard let source = edge.getSource() else { continue }
                adjFarPort.append(Int32(source.id))
                incoming += 1
            }
            adjIncomingCount.append(incoming)
            for edge in port.getOutgoingEdges() {
                guard let target = edge.getTarget() else { continue }
                adjFarPort.append(Int32(target.id))
            }
            adjStart.append(Int32(adjFarPort.count))
        }

        // Node attribute slots + counting flags.
        var portConstraintsFixed = [Bool](); portConstraintsFixed.reserveCapacity(nodeCount)
        var isNormalNode = [Bool](); isNormalNode.reserveCapacity(nodeCount)
        var isExternalPortDummy = [Bool](); isExternalPortDummy.reserveCapacity(nodeCount)
        var isLongEdgeNode = [Bool](); isLongEdgeNode.reserveCapacity(nodeCount)
        var isNorthSouthDummy = [Bool](); isNorthSouthDummy.reserveCapacity(nodeCount)
        var layerHasNorthSouthPorts = [Bool](repeating: false, count: layerCount)
        var hasHyperEdgesEastOfIndex = [Bool](repeating: false, count: layerCount)
        for (i, node) in objectNodes.enumerated() {
            let pc = node.getProperty("org.eclipse.elk.portConstraints") as? PortConstraints ?? .UNDEFINED
            portConstraintsFixed.append(pc.isOrderFixed())
            let type = node.getType()
            isNormalNode.append(type == .NORMAL)
            isExternalPortDummy.append(type == .EXTERNAL_PORT)
            isLongEdgeNode.append(type == .LONG_EDGE)
            isNorthSouthDummy.append(type == .NORTH_SOUTH_PORT)
            let l = Int(nodeLayer[i])
            if type == .NORTH_SOUTH_PORT { layerHasNorthSouthPorts[l] = true }
            // ACC.initAtPortLevel's hyperedge routing, off raw edge counts.
            for pi in Int(nodePortStart[i])..<Int(nodePortStart[i + 1]) where portDegree[pi] > 1 {
                if portSide[pi] == 2 { // EAST
                    hasHyperEdgesEastOfIndex[l] = true
                } else if portSide[pi] == 4, l > 0 { // WEST
                    hasHyperEdgesEastOfIndex[l - 1] = true
                }
            }
        }

        // Node-list properties → CSRs of flat ids. A referenced node outside
        // the traversal (impossible post-traversal) would be a contract
        // violation; assert rather than silently drop.
        func flatId(_ node: LNode) -> Int32 {
            guard let id = nodeIds[ObjectIdentifier(node)] else {
                assertionFailure("property references a node outside the traversal")
                return -1
            }
            return id
        }
        var associatesStart: [Int32] = [0]
        var associates: [Int32] = []
        var inLayerSuccessorsStart: [Int32] = [0]
        var inLayerSuccessors: [Int32] = []
        for node in objectNodes {
            if let list: [LNode] = node.getProperty(InternalProperties.BARYCENTER_ASSOCIATES) as? [LNode] {
                for associate in list { associates.append(flatId(associate)) }
            }
            associatesStart.append(Int32(associates.count))
            if let list = node.getProperty(InternalProperties.IN_LAYER_SUCCESSOR_CONSTRAINTS) as? [LNode] {
                for successor in list { inLayerSuccessors.append(flatId(successor)) }
            }
            inLayerSuccessorsStart.append(Int32(inLayerSuccessors.count))
        }

        // Layout units: bucket members under their representative, preserving
        // traversal append order (Forster's dictionary insertion order), and
        // keep the node→representative direction for north-south counting.
        var unitBuckets = [[Int32]](repeating: [], count: nodeCount)
        var layoutUnitOf = [Int32](repeating: -1, count: nodeCount)
        for (i, node) in objectNodes.enumerated() {
            if let unit = node.getProperty(InternalProperties.IN_LAYER_LAYOUT_UNIT) as? LNode {
                let rep = flatId(unit)
                layoutUnitOf[i] = rep
                if rep >= 0 { unitBuckets[Int(rep)].append(Int32(i)) }
            }
        }
        var unitMembersStart = [Int32](); unitMembersStart.reserveCapacity(nodeCount + 1)
        unitMembersStart.append(0)
        var unitMembers: [Int32] = []
        for bucket in unitBuckets {
            unitMembers.append(contentsOf: bucket)
            unitMembersStart.append(Int32(unitMembers.count))
        }

        // Port properties (north/south machinery).
        var nsPortDummyNode = [Int32](); nsPortDummyNode.reserveCapacity(portCount)
        var dummyPortOrigin = [Int32](); dummyPortOrigin.reserveCapacity(portCount)
        for port in objectPorts {
            if let dummy = port.getProperty("portDummy") as? LNode {
                nsPortDummyNode.append(flatId(dummy))
            } else {
                nsPortDummyNode.append(-1)
            }
            if let origin = port.getProperty("origin") as? LPort {
                dummyPortOrigin.append(Int32(origin.id))
            } else {
                dummyPortOrigin.append(-1)
            }
        }

        self.layerCount = layerCount
        self.nodeCount = nodeCount
        self.portCount = portCount
        self.layerStart = layerStart
        self.nodeLayer = nodeLayer
        self.nodePortStart = nodePortStart
        self.portNode = portNode
        self.portSide = portSide
        self.portDegree = portDegree
        self.portIncomingCount = portIncomingCount
        self.adjStart = adjStart
        self.adjIncomingCount = adjIncomingCount
        self.adjFarPort = adjFarPort
        self.portConstraintsFixed = portConstraintsFixed
        self.isNormalNode = isNormalNode
        self.isExternalPortDummy = isExternalPortDummy
        self.isLongEdgeNode = isLongEdgeNode
        self.isNorthSouthDummy = isNorthSouthDummy
        self.layoutUnitOf = layoutUnitOf
        self.layerHasNorthSouthPorts = layerHasNorthSouthPorts
        self.hasHyperEdgesEastOfIndex = hasHyperEdgesEastOfIndex
        self.usesObjectCounting = hasHyperEdgesEastOfIndex.contains(true)
        self.associatesStart = associatesStart
        self.associates = associates
        self.inLayerSuccessorsStart = inLayerSuccessorsStart
        self.inLayerSuccessors = inLayerSuccessors
        self.unitMembersStart = unitMembersStart
        self.unitMembers = unitMembers
        self.nsPortDummyNode = nsPortDummyNode
        self.dummyPortOrigin = dummyPortOrigin
        self.objectNodes = objectNodes
        self.objectPorts = objectPorts
    }

    /// `AbstractBarycenterPortDistributor.sideOrdinal` — the sortPorts order.
    package static func sideOrdinal(_ side: PortSide) -> UInt8 {
        switch side {
        case .UNDEFINED: return 0
        case .NORTH: return 1
        case .EAST: return 2
        case .SOUTH: return 3
        case .WEST: return 4
        }
    }
}
