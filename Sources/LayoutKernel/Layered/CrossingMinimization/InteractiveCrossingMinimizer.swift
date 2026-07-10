// Ported from elk-source/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p3order/InteractiveCrossingMinimizer.java
import Foundation

package final class InteractiveCrossingMinimizer {
    package enum _Keys {
        static let graphProperties = InternalProperties.GRAPH_PROPERTIES
        static let inLayerSuccessorConstraints = InternalProperties.IN_LAYER_SUCCESSOR_CONSTRAINTS
        static let originalDummyNodePosition = InternalProperties.ORIGINAL_DUMMY_NODE_POSITION
        static let origin = InternalProperties.ORIGIN
        static let originalBendpoints = InternalProperties.ORIGINAL_BENDPOINTS
        static let reversed = "reversed"
        static let longEdgeSource = InternalProperties.LONG_EDGE_SOURCE
        static let longEdgeTarget = InternalProperties.LONG_EDGE_TARGET
    }

    package static let INTERMEDIATE_PROCESSING_CONFIGURATION: LayoutProcessorConfiguration<LayeredPhases, LGraph> = {
        LayoutProcessorConfiguration<LayeredPhases, LGraph>.create()
            .addBefore(
                LayeredPhases.P3_NODE_ORDERING,
                IntermediateProcessorStrategy.LONG_EDGE_SPLITTER
            )
            .addBefore(
                LayeredPhases.P4_NODE_PLACEMENT,
                IntermediateProcessorStrategy.IN_LAYER_CONSTRAINT_PROCESSOR
            )
            .addAfter(
                LayeredPhases.P5_EDGE_ROUTING,
                IntermediateProcessorStrategy.LONG_EDGE_JOINER
            )
    }()

    package init() {}

    package func getLayoutProcessorConfiguration(
        _ graph: LGraph
    ) -> LayoutProcessorConfiguration<LayeredPhases, LGraph>? {
        let configuration = LayoutProcessorConfiguration<LayeredPhases, LGraph>.create(
            from: Self.INTERMEDIATE_PROCESSING_CONFIGURATION
        )
        let graphProperties = graph.getProperty(_Keys.graphProperties)
            as? Set<GraphProperties> ?? []
        if graphProperties.contains(.NON_FREE_PORTS) {
            configuration.addBefore(
                LayeredPhases.P3_NODE_ORDERING,
                IntermediateProcessorStrategy.PORT_LIST_SORTER
            )
        }
        return configuration
    }

    package func process(
        _ layeredGraph: LGraph,
        _ monitor: any IElkProgressMonitor
    ) {
        monitor.begin("Interactive crossing minimization", 1)

        var layerIndex = 0
        for layer in layeredGraph.getLayers() {
            layer.id = layerIndex
            layerIndex += 1
        }

        let nodeOrder = layeredGraph.getLayers().map { $0.getNodes() }
        let portDistributor = NodeRelativePortDistributor(nodeOrder.count)

        var portCount = 0
        layerIndex = 0
        for layer in layeredGraph {
            var horizPos: Double = 0
            var nodeCount = 0
            for node in layer.getNodes() {
                if node.getPosition().x > 0 {
                    horizPos += node.getPosition().x + node.getSize().x / 2
                    nodeCount += 1
                }
                for port in node.getPorts() {
                    port.id = portCount
                    portCount += 1
                }
            }

            if nodeCount > 0 {
                horizPos /= Double(nodeCount)
            }

            let nodes = layer.getNodes()
            var positions: [ObjectIdentifier: Double] = [:]
            positions.reserveCapacity(nodes.count)

            for (index, node) in nodes.enumerated() {
                node.id = index
                let y = getPos(node, horizPos)
                positions[ObjectIdentifier(node)] = y

                if node.getType() == .LONG_EDGE {
                    node.setProperty(_Keys.originalDummyNodePosition, y)
                }
            }

            let sortedNodes = nodes.sorted { n1, n2 in
                let p1 = positions[ObjectIdentifier(n1)] ?? 0
                let p2 = positions[ObjectIdentifier(n2)] ?? 0
                let compare = p1 == p2 ? 0 : (p1 < p2 ? -1 : 1)

                if compare == 0 {
                    let node1Successors = n1.getProperty(_Keys.inLayerSuccessorConstraints)
                        as? [LNode] ?? []
                    let node2Successors = n2.getProperty(_Keys.inLayerSuccessorConstraints)
                        as? [LNode] ?? []

                    if node1Successors.contains(where: { $0 === n2 }) {
                        return true
                    }
                    if node2Successors.contains(where: { $0 === n1 }) {
                        return false
                    }
                }

                return p1 < p2
            }

            layer.setNodes(sortedNodes)
            _ = portDistributor.distributePortsWhileSweeping(nodeOrder, layerIndex, true)
            layerIndex += 1
        }

        monitor.done()
    }

    package func getPos(
        _ node: LNode,
        _ horizPos: Double
    ) -> Double {
        switch node.getType() {
        case .LONG_EDGE:
            guard let edge = node.getProperty(_Keys.origin) as? LEdge else {
                break
            }

            var bendpoints = edge.getProperty(_Keys.originalBendpoints) as? KVectorChain
                ?? KVectorChain()
            if edge.getProperty(_Keys.reversed) as? Bool ?? false {
                bendpoints = KVectorChain.reverse(bendpoints)
            }

            let source = node.getProperty(_Keys.longEdgeSource) as? LPort
            if let source {
                let sourcePoint = source.getAbsoluteAnchor()
                if horizPos <= sourcePoint.x {
                    return sourcePoint.y
                }
                bendpoints.addFirst(sourcePoint)
            }

            let target = node.getProperty(_Keys.longEdgeTarget) as? LPort
            if let target {
                let targetPoint = target.getAbsoluteAnchor()
                if targetPoint.x <= horizPos {
                    return targetPoint.y
                }
                bendpoints.addLast(targetPoint)
            }

            let points = bendpoints.toArray()
            if points.count >= 2 {
                var point1 = points[0]
                var point2 = points[1]
                var i = 1
                while point2.x < horizPos && i + 1 < points.count {
                    point1 = point2
                    i += 1
                    point2 = points[i]
                }

                if point2.x == point1.x {
                    return point1.y
                }
                return point1.y + (horizPos - point1.x) / (point2.x - point1.x) * (point2.y - point1.y)
            }

        case .NORTH_SOUTH_PORT:
            guard let firstPort = node.getPorts().first,
                  let originPort = firstPort.getProperty(_Keys.origin) as? LPort,
                  let originNode = originPort.getNode()
            else {
                break
            }

            switch originPort.getSide() {
            case .NORTH:
                return originNode.getPosition().y
            case .SOUTH:
                return originNode.getPosition().y + originNode.getSize().y
            case .EAST, .WEST, .UNDEFINED:
                break
            }

        default:
            break
        }

        return node.getInteractiveReferencePoint().y
    }
}
