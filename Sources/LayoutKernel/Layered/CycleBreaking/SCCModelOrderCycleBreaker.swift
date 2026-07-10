// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p1cycles/SCCModelOrderCycleBreaker.java

import Foundation

package class SCCModelOrderCycleBreaker {
    /// List of strongly connected components calculated by tarjan.
    package var stronglyConnectedComponents: [[LNode]] = []

    /// Maps node to id of its strongly connected component.
    package var nodeToSCCID: [LNode: Int] = [:]

    /// The edges to reverse.
    package var revEdges: [LEdge] = []

    /// The graph.
    package var graph: LGraph?

    package static let INTERMEDIATE_PROCESSING_CONFIGURATION =
        LayoutProcessorConfiguration<LayeredPhases, LGraph>.create()
            .addAfter(
                LayeredPhases.P5_EDGE_ROUTING,
                IntermediateProcessorStrategy.REVERSED_EDGE_RESTORER
            )

    package init() {}

    package func getLayoutProcessorConfiguration(
        _ graph: LGraph
    ) -> LayoutProcessorConfiguration<LayeredPhases, LGraph>? {
        _ = graph
        return Self.INTERMEDIATE_PROCESSING_CONFIGURATION
    }

    package func process(
        _ layeredGraph: LGraph,
        _ monitor: any IElkProgressMonitor
    ) {
        beginMonitor(monitor, "Model order cycle breaking", 1)

        graph = layeredGraph
        revEdges.removeAll(keepingCapacity: false)

        // One needs an offset to make sure that the model order of nodes with port constraints
        // is always lower/higher than that of other nodes.
        let offset = max(layeredGraph.getLayerlessNodes().count, maxModelOrderNodesFallback(for: layeredGraph))
        let bigOffset = offset * cbNumModelOrderGroupsFallback(for: layeredGraph)

        while true {
            var tarjan = Tarjan(
                edgesToBeReversed: revEdges,
                stronglyConnectedComponents: &stronglyConnectedComponents,
                nodeToSCCID: &nodeToSCCID
            )
            tarjan.resetTarjan(layeredGraph)
            tarjan.tarjan(layeredGraph)

            stronglyConnectedComponents = tarjan.stronglyConnectedComponents
            nodeToSCCID = tarjan.nodeToSCCID

            // If no strongly connected components remain, the graph is acyclic.
            if stronglyConnectedComponents.isEmpty {
                break
            }

            // highest model order only incoming
            findNodes(offset, bigOffset)

            // reverse the gathered edges
            for edge in revEdges {
                reverse(edge, in: layeredGraph)
                layeredGraph.setProperty(InternalProperties.CYCLIC, true)
            }

            stronglyConnectedComponents.removeAll(keepingCapacity: false)
            nodeToSCCID.removeAll(keepingCapacity: false)
            revEdges.removeAll(keepingCapacity: false)
        }

        doneMonitor(monitor)
    }

    /// Java: SCCModelOrderCycleBreaker#findNodes(int offset, int bigOffset)
    package func findNodes(_ offset: Int, _ bigOffset: Int) {
        let calculator = GroupModelOrderCalculator()
        let enforceGroupModelOrder = shouldEnforceGroupModelOrder()

        // All strongly connected components have one maximum element for which we can reverse all outgoing edges.
        for component in stronglyConnectedComponents {
            var maxNode: LNode?
            var maxModelOrder = Int.min

            for node in component {
                let currentModelOrder = enforceGroupModelOrder
                    ? calculator.computeConstraintGroupModelOrder(node, bigOffset, offset)
                    : calculator.computeConstraintModelOrder(node, offset)

                if maxNode == nil || maxModelOrder < currentModelOrder {
                    maxNode = node
                    maxModelOrder = currentModelOrder
                }
            }

            guard let maxNode else {
                continue
            }

            for edge in maxNode.getOutgoingEdges() {
                // Reverse all edges to the same strongly connected component.
                if let targetNode = edge.getTarget()?.getNode(), containsIdentity(targetNode, in: component) {
                    revEdges.append(edge)
                }
            }
        }
    }

    package func shouldEnforceGroupModelOrder() -> Bool {
        ModelOrderPropertyScaffolding
            .groupOrderStrategy(for: graph) == .ENFORCED
    }

    package func maxModelOrderNodesFallback(for graph: LGraph) -> Int {
        ModelOrderPropertyScaffolding
            .maxModelOrderNodes(for: graph) ?? 1
    }

    package func cbNumModelOrderGroupsFallback(for graph: LGraph) -> Int {
        ModelOrderPropertyScaffolding
            .cbNumModelOrderGroups(for: graph) ?? 1
    }

    package func reverse(
        _ edge: LEdge,
        in layeredGraph: LGraph
    ) {
        edge.reverse(layeredGraph, false)
    }

    package func containsIdentity(
        _ node: LNode,
        in component: [LNode]
    ) -> Bool {
        component.contains(where: { $0 === node })
    }

    package func beginMonitor(
        _ monitor: any IElkProgressMonitor,
        _ taskName: String,
        _ totalWork: Int
    ) {
        (monitor as? _SCCModelOrderCycleBreakerProgressMonitorCompat)?.begin(taskName, totalWork)
    }

    package func doneMonitor(_ monitor: any IElkProgressMonitor) {
        (monitor as? _SCCModelOrderCycleBreakerProgressMonitorCompat)?.done()
    }
}

package protocol _SCCModelOrderCycleBreakerProgressMonitorCompat {
    func begin(_ taskName: String, _ totalWork: Int)
    func done()
}
