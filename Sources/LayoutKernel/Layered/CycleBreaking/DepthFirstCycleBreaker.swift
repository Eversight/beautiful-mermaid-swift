// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p1cycles/DepthFirstCycleBreaker.java

import Foundation

package final class DepthFirstCycleBreaker {
    package static let INTERMEDIATE_PROCESSING_CONFIGURATION =
        LayoutProcessorConfiguration<LayeredPhases, LGraph>.create()
            .addAfter(
                LayeredPhases.P5_EDGE_ROUTING,
                IntermediateProcessorStrategy.REVERSED_EDGE_RESTORER
            )

    package var sources: [LNode]?
    package var visited: [Bool]?
    package var active: [Bool]?
    package var edgesToBeReversed: [LEdge]?

    package init() {}

    package func getLayoutProcessorConfiguration(
        _ graph: LGraph
    ) -> LayoutProcessorConfiguration<LayeredPhases, LGraph>? {
        _ = graph
        return Self.INTERMEDIATE_PROCESSING_CONFIGURATION
    }

    package func process(
        _ graph: LGraph,
        _ monitor: any IElkProgressMonitor
    ) {
        beginMonitor(monitor, "Depth-first cycle removal", 1)

        let nodes = graph.getLayerlessNodes()
        let nodeCount = nodes.count

        sources = []
        visited = Array(repeating: false, count: nodeCount)
        active = Array(repeating: false, count: nodeCount)
        edgesToBeReversed = []

        for (index, node) in nodes.enumerated() {
            node.id = index
            if node.getIncomingEdges().isEmpty {
                sources?.append(node)
            }
        }

        if let localSources = sources {
            for source in localSources {
                dfs(source)
            }
        }

        for index in 0..<nodeCount {
            guard let seen = visited, !seen[index] else {
                continue
            }
            let node = nodes[index]
            dfs(node)
        }

        if let reversed = edgesToBeReversed {
            for edge in reversed {
                reverse(edge, in: graph)
                graph.setProperty(InternalProperties.CYCLIC, true)
            }
        }

        sources = nil
        visited = nil
        active = nil
        edgesToBeReversed = nil
        doneMonitor(monitor)
    }

    package func dfs(_ node: LNode) {
        guard var seen = visited, var activeFlags = active else {
            return
        }
        if seen[node.id] {
            return
        }

        seen[node.id] = true
        activeFlags[node.id] = true
        visited = seen
        active = activeFlags

        for outgoing in node.getOutgoingEdges() {
            if outgoing.isSelfLoop() {
                continue
            }
            guard let target = outgoing.getTarget()?.getNode() else {
                continue
            }

            if active?[target.id] == true {
                edgesToBeReversed?.append(outgoing)
            } else {
                dfs(target)
            }
        }

        active?[node.id] = false
    }

    package func reverse(
        _ edge: LEdge,
        in graph: LGraph
    ) {
        edge.reverse(graph, true)
    }

    package func beginMonitor(
        _ monitor: any IElkProgressMonitor,
        _ taskName: String,
        _ totalWork: Int
    ) {
        (monitor as? _DepthFirstCycleBreakerProgressMonitorCompat)?.begin(taskName, totalWork)
    }

    package func doneMonitor(_ monitor: any IElkProgressMonitor) {
        (monitor as? _DepthFirstCycleBreakerProgressMonitorCompat)?.done()
    }
}

package protocol _DepthFirstCycleBreakerProgressMonitorCompat {
    func begin(_ taskName: String, _ totalWork: Int)
    func done()
}
