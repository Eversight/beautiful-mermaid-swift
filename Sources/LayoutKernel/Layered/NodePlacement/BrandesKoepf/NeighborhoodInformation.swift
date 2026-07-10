import Foundation

package final class NeighborhoodInformation {
    package var nodeCount: Int = 0
    package var layerIndex: [Int] = []
    package var nodeIndex: [Int] = []
    package var leftNeighbors: [[Pair<
        LNode,
        LEdge
    >]] = []
    package var rightNeighbors: [[Pair<
        LNode,
        LEdge
    >]] = []

    package init() {}

    package func cleanup() {
        layerIndex.removeAll(keepingCapacity: false)
        nodeIndex.removeAll(keepingCapacity: false)
        leftNeighbors.removeAll(keepingCapacity: false)
        rightNeighbors.removeAll(keepingCapacity: false)
    }

    package static func buildFor(
        _ graph: LGraph
    ) -> NeighborhoodInformation {
        let ni = NeighborhoodInformation()

        ni.nodeCount = 0
        for layer in graph {
            ni.nodeCount += layer.getNodes().count
        }

        var layerId = 0
        var layerPos = 0
        ni.layerIndex = Array(repeating: 0, count: graph.getLayers().count)

        var nodeId = 0
        ni.nodeIndex = Array(repeating: 0, count: ni.nodeCount)
        for layer in graph.getLayers() {
            layer.id = layerId
            ni.layerIndex[layer.id] = layerPos
            layerId += 1
            layerPos += 1

            var nodePos = 0
            for node in layer.getNodes() {
                node.id = nodeId
                ni.nodeIndex[node.id] = nodePos
                nodeId += 1
                nodePos += 1
            }
        }

        ni.leftNeighbors = Array(repeating: [], count: ni.nodeCount)
        determineAllLeftNeighbors(ni, graph)
        ni.rightNeighbors = Array(repeating: [], count: ni.nodeCount)
        determineAllRightNeighbors(ni, graph)

        return ni
    }

    package static func determineAllRightNeighbors(
        _ ni: NeighborhoodInformation,
        _ graph: LGraph
    ) {
        for layer in graph {
            for node in layer {
                var result: [Pair<
                    LNode,
                    LEdge
                >] = []
                var maxPriority = 0

                for edge in node.getOutgoingEdges() {
                    if edge.isSelfLoop() || edge.isInLayerEdge() {
                        continue
                    }

                    let edgePriority: Int =
                        edge.getProperty(LayeredOptions.PRIORITY_STRAIGHTNESS)
                        ?? 0

                    if edgePriority > maxPriority {
                        maxPriority = edgePriority
                        result.removeAll(keepingCapacity: true)
                    }
                    if edgePriority == maxPriority, let targetNode = edge.getTarget()?.getNode() {
                        result.append(
                            Pair<
                                LNode,
                                LEdge
                            >.of(targetNode, edge)
                        )
                    }
                }

                ni.rightNeighbors[node.id] = sortNeighbors(result, ni.nodeIndex)
            }
        }
    }

    package static func determineAllLeftNeighbors(
        _ ni: NeighborhoodInformation,
        _ graph: LGraph
    ) {
        for layer in graph {
            for node in layer {
                var result: [Pair<
                    LNode,
                    LEdge
                >] = []
                var maxPriority = 0

                for edge in node.getIncomingEdges() {
                    if edge.isSelfLoop() || edge.isInLayerEdge() {
                        continue
                    }

                    let edgePriority: Int =
                        edge.getProperty(LayeredOptions.PRIORITY_STRAIGHTNESS)
                        ?? 0

                    if edgePriority > maxPriority {
                        maxPriority = edgePriority
                        result.removeAll(keepingCapacity: true)
                    }
                    if edgePriority == maxPriority, let sourceNode = edge.getSource()?.getNode() {
                        result.append(
                            Pair<
                                LNode,
                                LEdge
                            >.of(sourceNode, edge)
                        )
                    }
                }

                ni.leftNeighbors[node.id] = sortNeighbors(result, ni.nodeIndex)
            }
        }
    }

    package static func sortNeighbors(
        _ list: [Pair<
            LNode,
            LEdge
        >],
        _ nodeIndex: [Int]
    ) -> [Pair<
        LNode,
        LEdge
    >] {
        let indexed = list.enumerated()
        return indexed.sorted { lhs, rhs in
            let lhsPos = lhs.element.getFirst().map { nodeIndex[$0.id] } ?? 0
            let rhsPos = rhs.element.getFirst().map { nodeIndex[$0.id] } ?? 0
            if lhsPos == rhsPos {
                return lhs.offset < rhs.offset
            }
            return lhsPos < rhsPos
        }.map(\.element)
    }
}

