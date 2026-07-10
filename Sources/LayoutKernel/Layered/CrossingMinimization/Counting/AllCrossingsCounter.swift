// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p3order/counting/AllCrossingsCounter.java

import Foundation

package final class AllCrossingsCounter:
    IInitializable
{
    package var crossingCounter: CrossingsCounter?
    package var hasHyperEdgesEastOfIndex: [Bool]
    package var hyperedgeCrossingsCounter: HyperedgeCrossingsCounter?

    package var inLayerEdgeCounts: [Int]
    package var hasNorthSouthPorts: [Bool]
    package var nPorts: Int

    private let graph: [[LNode]]

    package init(_ graph: [[LNode]]) {
        self.graph = graph
        inLayerEdgeCounts = Array(repeating: 0, count: graph.count)
        hasNorthSouthPorts = Array(repeating: false, count: graph.count)
        hasHyperEdgesEastOfIndex = Array(repeating: false, count: graph.count)
        nPorts = 0
    }

    package func countAllCrossings(_ currentOrder: [[LNode]]) -> Int {
        if currentOrder.isEmpty {
            return 0
        }

        guard let crossingCounter else {
            return 0
        }

        var crossings = crossingCounter.countInLayerCrossingsOnSide(currentOrder[0], .WEST)
        let eastCross = crossingCounter.countInLayerCrossingsOnSide(currentOrder[currentOrder.count - 1], .EAST)
        crossings += eastCross

        for layerIndex in currentOrder.indices {
            let layerCross = countCrossingsAt(layerIndex, currentOrder)
            crossings += layerCross
        }

        return crossings
    }

    package func countCrossingsAt(_ layerIndex: Int, _ currentOrder: [[LNode]]) -> Int {
        var totalCrossings = 0
        let leftLayer = currentOrder[layerIndex]

        if layerIndex < currentOrder.count - 1 {
            let rightLayer = currentOrder[layerIndex + 1]
            if hasHyperEdgesEastOfIndex[layerIndex] {
                totalCrossings = hyperedgeCrossingsCounter?.countCrossings(leftLayer, rightLayer) ?? 0
                if let crossingCounter {
                    totalCrossings += crossingCounter.countInLayerCrossingsOnSide(leftLayer, .EAST)
                    totalCrossings += crossingCounter.countInLayerCrossingsOnSide(rightLayer, .WEST)
                }
            } else {
                totalCrossings = crossingCounter?.countCrossingsBetweenLayers(leftLayer, rightLayer) ?? 0
            }
        }

        if hasNorthSouthPorts[layerIndex] {
            totalCrossings += crossingCounter?.countNorthSouthPortCrossingsInLayer(leftLayer) ?? 0
        }

        return totalCrossings
    }

    package func initAtNodeLevel(
        _ l: Int,
        _ n: Int,
        _ nodeOrder: [[LNode]]
    ) {
        guard l >= 0, l < nodeOrder.count, n >= 0, n < nodeOrder[l].count else {
            return
        }
        if nodeOrder[l][n].getType() == .NORTH_SOUTH_PORT {
            hasNorthSouthPorts[l] = true
        }
    }

    package func initAtPortLevel(
        _ l: Int,
        _ n: Int,
        _ p: Int,
        _ nodeOrder: [[LNode]]
    ) {
        guard l >= 0, l < nodeOrder.count, n >= 0, n < nodeOrder[l].count else {
            return
        }
        let ports = nodeOrder[l][n].getPorts()
        guard p >= 0, p < ports.count else {
            return
        }

        let port = ports[p]
        port.id = nPorts
        nPorts += 1

        if port.getOutgoingEdges().count + port.getIncomingEdges().count > 1 {
            if port.getSide() == .EAST {
                hasHyperEdgesEastOfIndex[l] = true
            } else if port.getSide() == .WEST, l > 0 {
                hasHyperEdgesEastOfIndex[l - 1] = true
            }
        }
    }

    package func initAtEdgeLevel(
        _ l: Int,
        _ n: Int,
        _ p: Int,
        _ e: Int,
        _ edge: LEdge,
        _ nodeOrder: [[LNode]]
    ) {
        _ = e
        guard l >= 0, l < nodeOrder.count, n >= 0, n < nodeOrder[l].count else {
            return
        }
        let ports = nodeOrder[l][n].getPorts()
        guard p >= 0, p < ports.count else {
            return
        }

        let port = ports[p]
        if edge.getSource() === port,
           let sourceLayer = edge.getSource()?.getNode()?.getLayer(),
           let targetLayer = edge.getTarget()?.getNode()?.getLayer(),
           sourceLayer === targetLayer
        {
            inLayerEdgeCounts[l] += 1
        }
    }

    package func initAfterTraversal() {
        let portPos = Array(repeating: 0, count: nPorts)
        hyperedgeCrossingsCounter = HyperedgeCrossingsCounter(
            inLayerEdgeCounts,
            hasNorthSouthPorts,
            portPos
        )
        crossingCounter = CrossingsCounter(portPos)
        // Port ids are dense now — build the flat adjacency for the counting
        // hot loops (see docs/SweepEngineDesign.md, S1).
        crossingCounter?.topology = SweepTopology(nodeOrder: graph, portCount: nPorts)
    }
}
