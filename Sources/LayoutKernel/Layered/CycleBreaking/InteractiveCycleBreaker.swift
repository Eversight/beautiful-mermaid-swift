// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p1cycles/InteractiveCycleBreaker.java

import Foundation

package final class InteractiveCycleBreaker {
    package static let INTERMEDIATE_PROCESSING_CONFIGURATION =
        LayoutProcessorConfiguration<LayeredPhases, LGraph>.create()
            .addBefore(
                LayeredPhases.P1_CYCLE_BREAKING,
                IntermediateProcessorStrategy.INTERACTIVE_EXTERNAL_PORT_POSITIONER
            )
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
        beginMonitor(monitor, "Interactive cycle breaking", 1)

        var revEdges: [LEdge] = []

        // Gather edges that point to the "wrong" horizontal direction.
        for source in layeredGraph.getLayerlessNodes() {
            source.id = 1
            let sourcex = interactiveReferenceX(source)
            for port in source.getPorts(.OUTPUT) {
                for edge in port.getOutgoingEdges() {
                    guard let target = edge.getTarget()?.getNode(), target !== source else {
                        continue
                    }
                    let targetx = interactiveReferenceX(target)
                    if targetx < sourcex {
                        revEdges.append(edge)
                    }
                }
            }
        }

        for edge in revEdges {
            reverse(edge, in: layeredGraph)
        }

        // Additional DFS cycle check (mirrors Java fallback pass).
        revEdges.removeAll(keepingCapacity: true)
        for node in layeredGraph.getLayerlessNodes() where node.id > 0 {
            findCycles(node, &revEdges)
        }

        for edge in revEdges {
            reverse(edge, in: layeredGraph)
        }

        revEdges.removeAll(keepingCapacity: true)
        doneMonitor(monitor)
    }

    package func findCycles(
        _ node1: LNode,
        _ revEdges: inout [LEdge]
    ) {
        node1.id = -1
        for port in node1.getPorts(.OUTPUT) {
            for edge in port.getOutgoingEdges() {
                guard let node2 = edge.getTarget()?.getNode(), node1 !== node2 else {
                    continue
                }
                if node2.id < 0 {
                    revEdges.append(edge)
                } else if node2.id > 0 {
                    findCycles(node2, &revEdges)
                }
            }
        }
        node1.id = 0
    }

    package func interactiveReferenceX(_ node: LNode) -> Double {
        node.getInteractiveReferencePoint().x
    }

    package func reverse(
        _ edge: LEdge,
        in layeredGraph: LGraph
    ) {
        edge.reverse(layeredGraph, true)
    }

    package func beginMonitor(
        _ monitor: any IElkProgressMonitor,
        _ taskName: String,
        _ totalWork: Int
    ) {
        (monitor as? _InteractiveCycleBreakerProgressMonitorCompat)?.begin(taskName, totalWork)
    }

    package func doneMonitor(_ monitor: any IElkProgressMonitor) {
        (monitor as? _InteractiveCycleBreakerProgressMonitorCompat)?.done()
    }
}

package protocol _InteractiveCycleBreakerProgressMonitorCompat {
    func begin(_ taskName: String, _ totalWork: Int)
    func done()
}
