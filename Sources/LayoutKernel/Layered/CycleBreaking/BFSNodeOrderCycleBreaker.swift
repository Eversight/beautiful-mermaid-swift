// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p1cycles/BFSNodeOrderCycleBreaker.java

import Foundation

package final class BFSNodeOrderCycleBreaker {
    package static let INTERMEDIATE_PROCESSING_CONFIGURATION =
        LayoutProcessorConfiguration<LayeredPhases, LGraph>.create()
            .addAfter(
                LayeredPhases.P5_EDGE_ROUTING,
                IntermediateProcessorStrategy.REVERSED_EDGE_RESTORER
            )

    package var sources: [LNode] = []
    package var sinks: [LNode] = []
    package var sourceIds: Set<ObjectIdentifier> = []
    package var sinkIds: Set<ObjectIdentifier> = []
    package var visited: [Bool] = []
    package var bfsQueue = ArrayDeque<LNode>()
    package var edgesToBeReversed: [LEdge] = []
    package var graph: LGraph?

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
        beginMonitor(monitor, "Breadth-first cycle removal", 1)

        self.graph = graph
        let nodes = graph.getLayerlessNodes()

        bfsQueue = ArrayDeque()
        sources = []
        sinks = []
        sourceIds = []
        sinkIds = []
        visited = Array(repeating: false, count: nodes.count)
        edgesToBeReversed = []

        for (index, node) in nodes.enumerated() {
            node.id = index
            if node.getIncomingEdges().isEmpty {
                sources.append(node)
                sourceIds.insert(ObjectIdentifier(node))
            }
            if node.getOutgoingEdges().isEmpty {
                sinks.append(node)
                sinkIds.insert(ObjectIdentifier(node))
            }
        }

        for source in sources {
            bfsQueue.append(source)
            bfsLoop()
        }

        bfsLoop()

        var changed = true
        while changed {
            changed = false
            for i in 0..<nodes.count where !visited[i] {
                bfsQueue.append(nodes[i])
                changed = true
                break
            }
            bfsLoop()
        }

        for edge in edgesToBeReversed {
            reverse(edge, in: graph)
            graph.setProperty(InternalProperties.CYCLIC, true)
        }

        sources.removeAll(keepingCapacity: false)
        sinks.removeAll(keepingCapacity: false)
        sourceIds.removeAll(keepingCapacity: false)
        sinkIds.removeAll(keepingCapacity: false)
        visited.removeAll(keepingCapacity: false)
        bfsQueue.removeAll(keepingCapacity: false)
        edgesToBeReversed.removeAll(keepingCapacity: false)
        self.graph = nil

        doneMonitor(monitor)
    }

    package func bfsLoop() {
        while !bfsQueue.isEmpty {
            let node = bfsQueue.removeFirst()
            bfs(node)
        }
    }

    package func bfs(_ node: LNode) {
        let nodeId = node.id
        if nodeId < 0 || nodeId >= visited.count || visited[nodeId] {
            return
        }
        visited[nodeId] = true

        var modelOrderMap: [Int: [LEdge]] = [:]
        let groupModelOrder = shouldUseGroupModelOrder()

        for edge in node.getOutgoingEdges() {
            guard let target = edge.getTarget()?.getNode() else {
                continue
            }

            let key: Int
            if let targetModelOrder = modelOrderValue(target, groupModelOrder: groupModelOrder) {
                key = targetModelOrder
            } else {
                key = Int.max - modelOrderMap.count
            }
            modelOrderMap[key, default: []].append(edge)
        }

        for key in modelOrderMap.keys.sorted() {
            guard let edgesForKey = modelOrderMap[key], let representative = edgesForKey.first else {
                continue
            }
            if representative.isSelfLoop() {
                continue
            }

            guard let target = representative.getTarget()?.getNode() else {
                continue
            }

            let targetId = target.id
            let targetVisited = targetId >= 0 && targetId < visited.count && visited[targetId]
            if targetVisited && !sourceIds.contains(ObjectIdentifier(node)) && !sinkIds.contains(ObjectIdentifier(target)) {
                edgesToBeReversed.append(contentsOf: edgesForKey)
            } else {
                bfsQueue.append(target)
            }
        }
    }

    package func modelOrderValue(
        _ target: LNode,
        groupModelOrder: Bool
    ) -> Int? {
        guard let modelOrder = modelOrderProperty(for: target) else {
            return nil
        }

        if groupModelOrder {
            let maxGroupSize = maxModelOrderNodes()
            let groupId = cycleBreakingGroupId(for: target)
            return (maxGroupSize * groupId) + modelOrder
        }

        return modelOrder
    }

    package func shouldUseGroupModelOrder() -> Bool {
        ModelOrderPropertyScaffolding
            .groupOrderStrategy(for: graph) == .ENFORCED
    }

    package func modelOrderProperty(for node: LNode) -> Int? {
        ModelOrderPropertyScaffolding
            .modelOrder(for: node) ?? node.id
    }

    package func cycleBreakingGroupId(for node: LNode) -> Int {
        ModelOrderPropertyScaffolding
            .cycleBreakingGroupId(for: node) ?? 0
    }

    package func maxModelOrderNodes() -> Int {
        let fallbackCount = graph?.getLayerlessNodes().count ?? 1
        let configured = ModelOrderPropertyScaffolding
            .maxModelOrderNodes(for: graph) ?? 1
        return max(fallbackCount, configured)
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
        (monitor as? _BFSNodeOrderCycleBreakerProgressMonitorCompat)?.begin(taskName, totalWork)
    }

    package func doneMonitor(_ monitor: any IElkProgressMonitor) {
        (monitor as? _BFSNodeOrderCycleBreakerProgressMonitorCompat)?.done()
    }
}

package protocol _BFSNodeOrderCycleBreakerProgressMonitorCompat {
    func begin(_ taskName: String, _ totalWork: Int)
    func done()
}
