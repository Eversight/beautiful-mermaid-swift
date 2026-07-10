/// S2' step 4: flat port distribution mirroring
/// `AbstractBarycenterPortDistributor` and its two rank calculators
/// (`NodeRelativePortDistributor` / `LayerTotalPortDistributor`).
///
/// Float discipline: ranks and port barycenters are `Float`, accumulated in
/// exactly the object walk's order — `consumedRank` per layer in node order,
/// per-port sums in edge order (outgoing first, then incoming, matching
/// `iteratePortsAndCollectInLayerPorts`, which is the OPPOSITE of the
/// adjacency's storage order — slices make both orders available).
///
/// The object `sortPorts` also writes a `SORTED_PORTS_KEY` property; nothing
/// in the repo reads it (grep-verified), so the flat engine skips the write —
/// output bytes are unaffected.
extension SweepEngine {

    // MARK: Driver

    /// `distributePortsWhileSweeping(nodeOrder, currentIndex, isForwardSweep)`.
    /// Always returns false (barycenter distributors don't claim improvement).
    @discardableResult
    package mutating func distributePortsWhileSweeping(_ currentIndex: Int, forward: Bool) -> Bool {
        updateNodePositions(currentIndex)
        let side: UInt8 = forward ? 4 : 2 // WEST : EAST (sortPorts ordinals)

        let isNotFirstLayer = forward
            ? currentIndex != 0
            : currentIndex != Swift.max(0, nodeOrder.count - 1)

        if isNotFirstLayer {
            let fixedIndex = forward ? currentIndex - 1 : currentIndex + 1
            calculatePortRanks(layerIndex: fixedIndex, output: forward)
            for node in nodeOrder[currentIndex] {
                distributePorts(node, side: side)
            }
            calculatePortRanks(layerIndex: currentIndex, output: !forward)
            // v1 subset: no nested graphs, so no node is skipped.
            for node in nodeOrder[fixedIndex] {
                distributePorts(node, side: side == 4 ? 2 : 4)
            }
        } else {
            for node in nodeOrder[currentIndex] {
                distributePorts(node, side: side)
            }
        }
        return false
    }

    package mutating func updateNodePositions(_ layerIndex: Int) {
        for (i, node) in nodeOrder[layerIndex].enumerated() {
            nodePosition[Int(node)] = Int32(i)
        }
    }

    // MARK: Rank calculation

    /// `calculatePortRanks(layer, portType)`: Float `consumedRank` threads
    /// through the layer in current node order.
    package mutating func calculatePortRanks(layerIndex: Int, output: Bool) {
        var consumedRank: Float = 0.0
        for node in nodeOrder[layerIndex] {
            if useNodeRelativeRanks {
                consumedRank += nodeRelativeRanks(node, rankSum: consumedRank, output: output)
            } else {
                consumedRank += layerTotalRanks(node, rankSum: consumedRank, output: output)
            }
        }
    }

    /// `NodeRelativePortDistributor.calculatePortRanks(node, rankSum, type)`.
    private mutating func nodeRelativeRanks(_ node: Int32, rankSum: Float, output: Bool) -> Float {
        let n = Int(node)
        let range = Int(graph.nodePortStart[n])..<Int(graph.nodePortStart[n + 1])

        if output {
            var outputCount = 0
            for pi in range where rawOutgoingCount(Int(portOrder[pi])) > 0 {
                outputCount += 1
            }
            let incr = 1.0 as Float / Float(outputCount + 1)
            var pos = rankSum + incr
            for pi in range {
                let port = Int(portOrder[pi])
                guard rawOutgoingCount(port) > 0 else { continue }
                portRank[port] = pos
                pos += incr
            }
        } else {
            var inputCount = 0
            var northInputCount = 0
            for pi in range {
                let port = Int(portOrder[pi])
                if graph.portIncomingCount[port] > 0 {
                    inputCount += 1
                    if graph.portSide[port] == 1 { northInputCount += 1 } // NORTH
                }
            }
            let incr = 1.0 as Float / Float(inputCount + 1)
            var northPos = rankSum + Float(northInputCount) * incr
            var restPos = rankSum + 1 - incr
            for pi in range {
                let port = Int(portOrder[pi])
                guard graph.portIncomingCount[port] > 0 else { continue }
                if graph.portSide[port] == 1 {
                    portRank[port] = northPos
                    northPos -= incr
                } else {
                    portRank[port] = restPos
                    restPos -= incr
                }
            }
        }
        return 1
    }

    /// `LayerTotalPortDistributor.calculatePortRanks(node, rankSum, type)`.
    private mutating func layerTotalRanks(_ node: Int32, rankSum: Float, output: Bool) -> Float {
        let n = Int(node)
        let range = Int(graph.nodePortStart[n])..<Int(graph.nodePortStart[n + 1])

        if output {
            var pos = 0
            for pi in range {
                let port = Int(portOrder[pi])
                guard rawOutgoingCount(port) > 0 else { continue }
                pos += 1
                portRank[port] = rankSum + Float(pos)
            }
            return Float(pos)
        } else {
            var inputCount = 0
            var northInputCount = 0
            for pi in range {
                let port = Int(portOrder[pi])
                if graph.portIncomingCount[port] > 0 {
                    inputCount += 1
                    if graph.portSide[port] == 1 { northInputCount += 1 }
                }
            }
            var northPos = rankSum + Float(northInputCount)
            var restPos = rankSum + Float(inputCount)
            for pi in range {
                let port = Int(portOrder[pi])
                guard graph.portIncomingCount[port] > 0 else { continue }
                if graph.portSide[port] == 1 {
                    portRank[port] = northPos
                    northPos -= 1
                } else {
                    portRank[port] = restPos
                    restPos -= 1
                }
            }
            return Float(inputCount)
        }
    }

    private func rawOutgoingCount(_ port: Int) -> Int32 {
        graph.portDegree[port] - graph.portIncomingCount[port]
    }

    // MARK: Port distribution on a node

    /// `distributePorts(node, side)`: only when port order is not fixed.
    package mutating func distributePorts(_ node: Int32, side: UInt8) {
        let n = Int(node)
        guard !graph.portConstraintsFixed[n] else { return }
        distributePortsOnSide(node, side: side)
        distributePortsOnSide(node, side: 3) // SOUTH
        distributePortsOnSide(node, side: 1) // NORTH
        sortPorts(node)
    }

    /// `distributePorts(node, ports)` for one side's ports in current order.
    private mutating func distributePortsOnSide(_ node: Int32, side: UInt8) {
        inLayerPortsScratch.removeAll(keepingCapacity: true)
        iteratePortsAndCollectInLayerPorts(node, side: side)
        if !inLayerPortsScratch.isEmpty {
            calculateInLayerPortsBarycenterValues(node)
        }
    }

    /// `iteratePortsAndCollectInLayerPorts`: outgoing edges first (sum +=),
    /// then incoming (sum -=); the first same-layer edge routes the port to
    /// the in-layer list. Self-loops ARE same-layer.
    private mutating func iteratePortsAndCollectInLayerPorts(_ node: Int32, side: UInt8) {
        distMinBarycenter = 0.0
        distMaxBarycenter = 0.0
        let n = Int(node)
        let myLayer = graph.nodeLayer[n]
        let layerSize = nodeOrder[Int(myLayer)].count
        let absurdlyLargeFloat = Float(2 * layerSize + 1)

        portLoop: for pi in Int(graph.nodePortStart[n])..<Int(graph.nodePortStart[n + 1]) {
            let port = Int(portOrder[pi])
            guard graph.portSide[port] == side else { continue }
            let northSouthPort = side == 1 || side == 3
            var sum: Float = 0.0

            if northSouthPort {
                let dummy = graph.nsPortDummyNode[port]
                guard dummy >= 0 else { continue }
                sum += dealWithNorthSouthPorts(absurdlyLargeFloat, port: port, dummy: dummy)
            } else {
                let rowStart = Int(graph.adjStart[port])
                let rowEnd = Int(graph.adjStart[port + 1])
                let incomingEnd = rowStart + Int(graph.adjIncomingCount[port])
                // Outgoing first…
                for i in incomingEnd..<rowEnd {
                    let farPort = Int(graph.adjFarPort[i])
                    let rank = portRank[farPort]
                    if graph.nodeLayer[Int(graph.portNode[farPort])] == myLayer {
                        inLayerPortsScratch.append(Int32(port))
                        continue portLoop
                    } else {
                        sum += rank
                    }
                }
                // …then incoming.
                for i in rowStart..<incomingEnd {
                    let farPort = Int(graph.adjFarPort[i])
                    let rank = portRank[farPort]
                    if graph.nodeLayer[Int(graph.portNode[farPort])] == myLayer {
                        inLayerPortsScratch.append(Int32(port))
                        continue portLoop
                    } else {
                        sum -= rank
                    }
                }
            }

            let degree = graph.portDegree[port]
            if degree > 0 {
                portBarycenter[port] = sum / Float(degree)
                distMinBarycenter = Swift.min(distMinBarycenter, portBarycenter[port])
                distMaxBarycenter = Swift.max(distMaxBarycenter, portBarycenter[port])
            } else if northSouthPort {
                portBarycenter[port] = sum
            }
        }
    }

    /// `calculateInLayerPortsBarycenterValues`.
    private mutating func calculateInLayerPortsBarycenterValues(_ node: Int32) {
        let n = Int(node)
        let nodeIndexInLayer = Int(nodePosition[n]) + 1
        let myLayer = graph.nodeLayer[n]
        let layerSize = nodeOrder[Int(myLayer)].count + 1

        for inLayerPort in inLayerPortsScratch {
            let port = Int(inLayerPort)
            var sum = 0
            var inLayerConnections = 0
            // getConnectedPorts(): predecessors (incoming) then successors.
            for i in Int(graph.adjStart[port])..<Int(graph.adjStart[port + 1]) {
                let farNode = Int(graph.portNode[Int(graph.adjFarPort[i])])
                if graph.nodeLayer[farNode] == myLayer {
                    sum += Int(nodePosition[farNode]) + 1
                    inLayerConnections += 1
                }
            }

            guard inLayerConnections > 0 else { continue }
            let barycenter = Float(sum) / Float(inLayerConnections)

            let side = graph.portSide[port]
            if side == 2 { // EAST
                if barycenter < Float(nodeIndexInLayer) {
                    portBarycenter[port] = distMinBarycenter - barycenter
                } else {
                    portBarycenter[port] = distMaxBarycenter + (Float(layerSize) - barycenter)
                }
            } else if side == 4 { // WEST
                if barycenter < Float(nodeIndexInLayer) {
                    portBarycenter[port] = distMaxBarycenter + barycenter
                } else {
                    portBarycenter[port] = distMinBarycenter - (Float(layerSize) - barycenter)
                }
            }
        }
    }

    /// `dealWithNorthSouthPorts`.
    private func dealWithNorthSouthPorts(_ absurdlyLargeFloat: Float, port: Int, dummy: Int32) -> Float {
        var input = false
        var output = false

        let d = Int(dummy)
        for pi in Int(graph.nodePortStart[d])..<Int(graph.nodePortStart[d + 1]) {
            let dummyPort = Int(portOrder[pi])
            if Int(graph.dummyPortOrigin[dummyPort]) == port {
                if rawOutgoingCount(dummyPort) > 0 {
                    output = true
                } else if graph.portIncomingCount[dummyPort] > 0 {
                    input = true
                }
            }
        }

        if input && (input != output) {
            let pos = Float(nodePosition[d])
            return graph.portSide[port] == 1 ? -pos : absurdlyLargeFloat - pos
        } else if output && (input != output) {
            return Float(nodePosition[d]) + 1.0
        } else if input && output {
            return graph.portSide[port] == 1 ? 0.0 : absurdlyLargeFloat / 2.0
        }
        return 0.0
    }

    /// `sortPorts`: stable sort of the node's FULL port list by
    /// (side ordinal, Float barycenter `<`).
    package mutating func sortPorts(_ node: Int32) {
        let n = Int(node)
        let range = Int(graph.nodePortStart[n])..<Int(graph.nodePortStart[n + 1])
        let sorted = portOrder[range].sorted { p1, p2 in
            let side1 = graph.portSide[Int(p1)]
            let side2 = graph.portSide[Int(p2)]
            if side1 != side2 {
                return side1 < side2
            }
            return portBarycenter[Int(p1)] < portBarycenter[Int(p2)]
        }
        portOrder.replaceSubrange(range, with: sorted)
        if let trace = LayerSweepCrossingMinimizer.trace {
            // The object hook records node.id (per-layer initial position).
            let layer = Int(graph.nodeLayer[n])
            trace.record(.portOrder(node: Int(node - graph.layerStart[layer]),
                                    portIds: sorted.map(Int.init)))
        }
    }
}
