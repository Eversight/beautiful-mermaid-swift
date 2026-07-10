// Ported from elk-source/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p3order/LayerSweepTypeDecider.java
import Foundation

package final class LayerSweepTypeDecider:
    IInitializable
{
    package enum _Keys {
        static let crossingMinimizationHierarchicalSweepiness =
            "org.eclipse.elk.layered.crossingMinimization.hierarchicalSweepiness"
        static let portConstraints = "org.eclipse.elk.portConstraints"
        static let portDummy = "portDummy"
        static let origin = "org.eclipse.elk.layered.origin"
    }

    package var nodeInfo: [[NodeInfo?]]
    // `unowned`: the GraphInfoHolder lazily creates and owns this decider,
    // so the decider never outlives it (a strong backref leaked both).
    package unowned let graphData: GraphInfoHolder

    package init() {
        graphData = GraphInfoHolder(
            LGraph(),
            .NONE,
            []
        )
        nodeInfo = []
    }

    package init(_ graphData: GraphInfoHolder) {
        self.graphData = graphData
        self.nodeInfo = Array(repeating: [], count: graphData.currentNodeOrder().count)
    }

    package func useBottomUp() -> Bool {
        // Java default is 0.1 (from Layered.melk), NOT 0
        let boundary = graphData.lGraph().getProperty(_Keys.crossingMinimizationHierarchicalSweepiness) as? Double ?? 0.1

        if bottomUpForced(boundary) || rootNode() || fixedPortOrder() || fewerThanTwoInOutEdges() {
            return true
        }

        if graphData.crossMinDeterministic() {
            return false
        }

        var pathsToRandom = 0
        var pathsToHierarchical = 0

        var nsPortDummies: [LNode] = []

        for layer in graphData.currentNodeOrder() {
            for node in layer {
                if isNorthSouthDummy(node) {
                    nsPortDummies.append(node)
                    continue
                }

                let currentNode = nodeInfoFor(node)

                if isExternalPortDummy(node) {
                    currentNode.hierarchicalInfluence = 1
                    if isEasternDummy(node) {
                        pathsToHierarchical += currentNode.connectedEdges
                    }
                } else if hasNoWesternPorts(node) {
                    currentNode.randomInfluence = 1
                } else if hasNoEasternPorts(node) {
                    pathsToRandom += currentNode.connectedEdges
                }

                for edge in node.getOutgoingEdges() {
                    pathsToRandom += currentNode.randomInfluence
                    pathsToHierarchical += currentNode.hierarchicalInfluence
                    transferInfoToTarget(currentNode, edge)
                }

                let northSouthPorts = node.getPortSideView(.NORTH) + node.getPortSideView(.SOUTH)
                for port in northSouthPorts {
                    if let nsDummy = port.getProperty(_Keys.portDummy) as? LNode {
                        pathsToRandom += currentNode.randomInfluence
                        pathsToHierarchical += currentNode.hierarchicalInfluence
                        transferInfoTo(currentNode, nsDummy)
                    }
                }
            }

            for node in nsPortDummies {
                let currentNode = nodeInfoFor(node)
                for edge in node.getOutgoingEdges() {
                    pathsToRandom += currentNode.randomInfluence
                    pathsToHierarchical += currentNode.hierarchicalInfluence
                    transferInfoToTarget(currentNode, edge)
                }
            }
            nsPortDummies.removeAll(keepingCapacity: true)
        }

        let allPaths = Double(pathsToRandom + pathsToHierarchical)
        let normalized = allPaths == 0 ? Double.infinity : Double(pathsToRandom - pathsToHierarchical) / allPaths
        return normalized >= boundary
    }

    package func fixedPortOrder() -> Bool {
        let constraints = graphData.parent().getProperty(_Keys.portConstraints) as? PortConstraints
            ?? .UNDEFINED
        return constraints.isOrderFixed()
    }

    package func transferInfoToTarget(
        _ currentNode: NodeInfo,
        _ edge: LEdge
    ) {
        transferInfoTo(currentNode, targetNode(edge))
    }

    package func transferInfoTo(
        _ currentNode: NodeInfo,
        _ target: LNode
    ) {
        let targetNodeInfo = nodeInfoFor(target)
        targetNodeInfo.transfer(currentNode)
        targetNodeInfo.connectedEdges += 1
    }

    package func fewerThanTwoInOutEdges() -> Bool {
        graphData.parent().getPortSideView(.EAST).count < 2
            && graphData.parent().getPortSideView(.WEST).count < 2
    }

    package func rootNode() -> Bool {
        !graphData.hasParent()
    }

    package func bottomUpForced(_ boundary: Double) -> Bool {
        boundary < -1
    }

    package func targetNode(_ edge: LEdge) -> LNode {
        edge.getTarget()?.getNode() ?? LNode(LGraph())
    }

    package func hasNoEasternPorts(_ node: LNode) -> Bool {
        let eastPorts = node.getPortSideView(.EAST)
        return eastPorts.isEmpty || !eastPorts.contains(where: { !$0.connectedEdges.isEmpty })
    }

    package func hasNoWesternPorts(_ node: LNode) -> Bool {
        let westPorts = node.getPortSideView(.WEST)
        return westPorts.isEmpty || !westPorts.contains(where: { !$0.connectedEdges.isEmpty })
    }

    package func isExternalPortDummy(_ node: LNode) -> Bool {
        node.getType() == .EXTERNAL_PORT
    }

    package func isNorthSouthDummy(_ node: LNode) -> Bool {
        node.getType() == .NORTH_SOUTH_PORT
    }

    package func isEasternDummy(_ node: LNode) -> Bool {
        originPort(node)?.getSide() == .EAST
    }

    package func originPort(_ node: LNode) -> LPort? {
        node.getProperty(_Keys.origin) as? LPort
    }

    package func nodeInfoFor(_ node: LNode) -> NodeInfo {
        guard let layerIndex = node.getLayer()?.id,
              layerIndex >= 0,
              layerIndex < nodeInfo.count,
              node.id >= 0,
              node.id < nodeInfo[layerIndex].count
        else {
            return NodeInfo()
        }

        if nodeInfo[layerIndex][node.id] == nil {
            nodeInfo[layerIndex][node.id] = NodeInfo()
        }
        guard let info = nodeInfo[layerIndex][node.id] else { return NodeInfo() }
        return info
    }

    package func initAtLayerLevel(
        _ l: Int,
        _ nodeOrder: [[LNode]]
    ) {
        guard l >= 0, l < nodeOrder.count else { return }
        if let first = nodeOrder[l].first,
           let layer = first.getLayer()
        {
            layer.id = l
        }
        nodeInfo[l] = Array(repeating: nil, count: nodeOrder[l].count)
    }

    package func initAtNodeLevel(
        _ l: Int,
        _ n: Int,
        _ nodeOrder: [[LNode]]
    ) {
        guard l >= 0, l < nodeOrder.count, n >= 0, n < nodeOrder[l].count else { return }
        let node = nodeOrder[l][n]
        node.id = n
        nodeInfo[l][n] = NodeInfo()
    }

    package final class NodeInfo: CustomStringConvertible {
        package var connectedEdges = 0
        package var hierarchicalInfluence = 0
        package var randomInfluence = 0

        package init() {}

        package func transfer(_ nodeInfo: NodeInfo) {
            hierarchicalInfluence += nodeInfo.hierarchicalInfluence
            randomInfluence += nodeInfo.randomInfluence
            connectedEdges += nodeInfo.connectedEdges
        }

        package var description: String {
            "NodeInfo [connectedEdges=\(connectedEdges), hierarchicalInfluence=\(hierarchicalInfluence), randomInfluence=\(randomInfluence)]"
        }
    }
}
