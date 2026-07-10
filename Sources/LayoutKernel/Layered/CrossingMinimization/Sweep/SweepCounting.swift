/// S3: flat crossing counting mirroring `AllCrossingsCounter` +
/// `CrossingsCounter` for graphs with NO hyperedge boundaries (the routing
/// flags are init-time constants; graphs with any hyperedge boundary stay on
/// the object counters wholesale — their tie-breaks are address-dependent and
/// the persistent `portPositions` stale history must not be split between
/// engines).
///
/// `flatPortPositions` persists across count calls exactly like the object
/// counter's array: entries not touched by the current pass keep whatever an
/// earlier pass wrote (observable via in-layer edges reaching outside the
/// current two-layer strip — contract §2). One `BinaryIndexedTree` sized for
/// the whole graph is reused (`clear()` == the object's fresh zeroed tree;
/// rank/add semantics don't depend on capacity).
extension SweepEngine {

    /// `AllCrossingsCounter.countAllCrossings(currentOrder)`.
    package mutating func flatCountAllCrossings() -> Int {
        guard !nodeOrder.isEmpty else { return 0 }

        var crossings = flatCountInLayerCrossingsOnSide(layerIndex: 0, side: 4) // WEST
        crossings += flatCountInLayerCrossingsOnSide(layerIndex: nodeOrder.count - 1, side: 2) // EAST

        for l in nodeOrder.indices {
            if l < nodeOrder.count - 1 {
                // usesObjectCounting == false ⇒ no hyperedge boundaries.
                crossings += flatCountCrossingsBetweenLayers(l)
            }
            if graph.layerHasNorthSouthPorts[l] {
                crossings += flatCountNorthSouthCrossings(layerIndex: l)
            }
        }
        return crossings
    }

    // MARK: Position walks (CrossingsCounter.initPositions on flat state)

    /// `getPorts(node, side, topDown)`: EAST natural when top-down, WEST
    /// natural when bottom-up; reversed otherwise. Appends the node's ports
    /// of `side` in that order, assigning sequential positions.
    private mutating func appendSidePorts(of node: Int32, side: UInt8, reversed: Bool) {
        let n = Int(node)
        let range = Int(graph.nodePortStart[n])..<Int(graph.nodePortStart[n + 1])
        if reversed {
            for pi in range.reversed() {
                let port = portOrder[pi]
                guard graph.portSide[Int(port)] == side else { continue }
                flatPortPositions[Int(port)] = countPortsScratch.count
                countPortsScratch.append(port)
            }
        } else {
            for pi in range {
                let port = portOrder[pi]
                guard graph.portSide[Int(port)] == side else { continue }
                flatPortPositions[Int(port)] = countPortsScratch.count
                countPortsScratch.append(port)
            }
        }
    }

    private mutating func prepareTree() -> BinaryIndexedTree {
        if let tree = countTree {
            tree.clear()
            return tree
        }
        let tree = BinaryIndexedTree(graph.portCount + 1)
        countTree = tree
        return tree
    }

    // MARK: Between-layer counting

    /// `countCrossingsBetweenLayers` (positions counter-clockwise: left layer
    /// EAST top-down, right layer WEST bottom-up) + the S1 flat count loop.
    private mutating func flatCountCrossingsBetweenLayers(_ leftIndex: Int) -> Int {
        countPortsScratch.removeAll(keepingCapacity: true)
        for node in nodeOrder[leftIndex] {
            appendSidePorts(of: node, side: 2, reversed: false) // EAST, top-down
        }
        for node in nodeOrder[leftIndex + 1].reversed() {
            appendSidePorts(of: node, side: 4, reversed: false) // WEST, bottom-up
        }

        let tree = prepareTree()
        var crossings = 0
        for port in countPortsScratch {
            let p = Int(port)
            let position = flatPortPositions[p]
            tree.removeAll(position)
            for i in Int(graph.adjStart[p])..<Int(graph.adjStart[p + 1]) {
                let endPosition = flatPortPositions[Int(graph.adjFarPort[i])]
                if endPosition > position {
                    crossings += tree.rank(endPosition)
                    countEndsScratch.append(endPosition)
                }
            }
            while let end = countEndsScratch.popLast() {
                tree.add(end)
            }
        }
        return crossings
    }

    // MARK: In-layer counting

    /// `countInLayerCrossingsOnSide`: positions top-down (EAST natural, WEST
    /// reversed per node), then the in-layer count. Dangling edges (absent
    /// from the adjacency) count toward `numBetweenLayerEdges` like the
    /// object's `isInLayer(dangling) == false` branch.
    private mutating func flatCountInLayerCrossingsOnSide(layerIndex: Int, side: UInt8) -> Int {
        countPortsScratch.removeAll(keepingCapacity: true)
        for node in nodeOrder[layerIndex] {
            appendSidePorts(of: node, side: side, reversed: side == 4)
        }

        let tree = prepareTree()
        let myLayer = Int32(layerIndex)
        var crossings = 0
        for port in countPortsScratch {
            let p = Int(port)
            let position = flatPortPositions[p]
            tree.removeAll(position)
            let rowStart = Int(graph.adjStart[p])
            let rowEnd = Int(graph.adjStart[p + 1])
            var numBetweenLayerEdges = Int(graph.portDegree[p]) - (rowEnd - rowStart) // dangling
            for i in rowStart..<rowEnd {
                let farPort = Int(graph.adjFarPort[i])
                if graph.nodeLayer[Int(graph.portNode[farPort])] == myLayer {
                    // Port-level self-loops land here with endPosition ==
                    // position, contributing nothing — same as the object's
                    // otherEndOf returning the port itself.
                    let endPosition = flatPortPositions[farPort]
                    if endPosition > position {
                        crossings += tree.rank(endPosition)
                        countEndsScratch.append(endPosition)
                    }
                } else {
                    numBetweenLayerEdges += 1
                }
            }
            crossings += tree.size() * numBetweenLayerEdges
            while let end = countEndsScratch.popLast() {
                tree.add(end)
            }
        }
        return crossings
    }

    // MARK: North-south counting

    /// `countNorthSouthPortCrossingsInLayer`: the layout-unit stack walk
    /// assigns positions, then targets resolve through portDummy/origin.
    private mutating func flatCountNorthSouthCrossings(layerIndex: Int) -> Int {
        countPortsScratch.removeAll(keepingCapacity: true)
        countStackScratch.removeAll(keepingCapacity: true)

        var lastLayoutUnit: Int32 = -1
        for node in nodeOrder[layerIndex] {
            let n = Int(node)

            // isLayoutUnitChanged(lastUnit, node)
            if lastLayoutUnit >= 0, lastLayoutUnit != node,
               graph.layoutUnitOf[n] >= 0, graph.layoutUnitOf[n] != lastLayoutUnit
            {
                emptyNorthSouthStack()
            }
            if graph.layoutUnitOf[n] >= 0 {
                lastLayoutUnit = graph.layoutUnitOf[n]
            }

            if graph.isNormalNode[n] {
                appendNorthSouthPorts(of: node, side: 1) // NORTH, dummy-bearing only
                emptyNorthSouthStack()
                appendNorthSouthPorts(of: node, side: 3) // SOUTH
            } else if graph.isNorthSouthDummy[n] {
                if let west = firstPort(of: node, side: 4) {
                    flatPortPositions[Int(west)] = countPortsScratch.count
                    countPortsScratch.append(west)
                }
                if firstPort(of: node, side: 2) != nil {
                    countStackScratch.append(node)
                }
            } else if graph.isLongEdgeNode[n] {
                let range = Int(graph.nodePortStart[n])..<Int(graph.nodePortStart[n + 1])
                for pi in range {
                    let port = portOrder[pi]
                    guard graph.portSide[Int(port)] == 4 else { continue } // WEST
                    flatPortPositions[Int(port)] = countPortsScratch.count
                    countPortsScratch.append(port)
                }
                for pi in range where graph.portSide[Int(portOrder[pi])] == 2 { // EAST
                    countStackScratch.append(node)
                }
            }
        }
        emptyNorthSouthStack()

        let tree = prepareTree()
        var crossings = 0
        for port in countPortsScratch {
            let p = Int(port)
            let position = flatPortPositions[p]
            tree.removeAll(position)

            let n = Int(graph.portNode[p])
            countTargetsScratch.removeAll(keepingCapacity: true)
            if graph.isNormalNode[n] {
                let dummy = graph.nsPortDummyNode[p]
                if dummy >= 0 {
                    let d = Int(dummy)
                    for pi in Int(graph.nodePortStart[d])..<Int(graph.nodePortStart[d + 1]) {
                        let dp = portOrder[pi]
                        countTargetsScratch.append((dp, Int(graph.portDegree[Int(dp)])))
                    }
                }
            } else if graph.isLongEdgeNode[n] {
                for pi in Int(graph.nodePortStart[n])..<Int(graph.nodePortStart[n + 1]) {
                    let other = portOrder[pi]
                    if other != port {
                        countTargetsScratch.append((other, Int(graph.portDegree[Int(other)])))
                        break
                    }
                }
            } else if graph.isNorthSouthDummy[n] {
                let origin = graph.dummyPortOrigin[p]
                if origin >= 0 {
                    countTargetsScratch.append((origin, Int(graph.portDegree[p])))
                }
            }

            for (target, degree) in countTargetsScratch {
                let endPosition = flatPortPositions[Int(target)]
                if endPosition > position {
                    crossings += tree.rank(endPosition) * degree
                    countEndsScratch.append(endPosition)
                }
            }
            while let end = countEndsScratch.popLast() {
                tree.add(end)
            }
        }
        return crossings
    }

    /// NORMAL-node north/south ports carrying a `portDummy` property, in
    /// current side order (`getNorthSouthPortsWithIncidentEdges`).
    private mutating func appendNorthSouthPorts(of node: Int32, side: UInt8) {
        let n = Int(node)
        for pi in Int(graph.nodePortStart[n])..<Int(graph.nodePortStart[n + 1]) {
            let port = portOrder[pi]
            guard graph.portSide[Int(port)] == side,
                  graph.nsPortDummyNode[Int(port)] >= 0 else { continue }
            flatPortPositions[Int(port)] = countPortsScratch.count
            countPortsScratch.append(port)
        }
    }

    private mutating func emptyNorthSouthStack() {
        while let dummy = countStackScratch.popLast() {
            guard let east = firstPort(of: dummy, side: 2) else { continue }
            flatPortPositions[Int(east)] = countPortsScratch.count
            countPortsScratch.append(east)
        }
    }

    private func firstPort(of node: Int32, side: UInt8) -> Int32? {
        let n = Int(node)
        for pi in Int(graph.nodePortStart[n])..<Int(graph.nodePortStart[n + 1])
        where graph.portSide[Int(portOrder[pi])] == side {
            return portOrder[pi]
        }
        return nil
    }
}
