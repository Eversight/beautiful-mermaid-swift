// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p1cycles/ModelOrderCycleBreaker.java

import Foundation

package final class ModelOrderCycleBreaker {
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
        _ = monitor

        var revEdges: [LEdge] = []

        let layerlessNodes = layeredGraph.getLayerlessNodes()
        let maxModelOrderNodes =
            ModelOrderPropertyScaffolding
                .maxModelOrderNodes(for: layeredGraph) ?? 1
        let cbNumModelOrderGroups =
            ModelOrderPropertyScaffolding
                .cbNumModelOrderGroups(for: layeredGraph) ?? 1
        let offset = max(layerlessNodes.count, maxModelOrderNodes)
        let bigOffset = offset * max(cbNumModelOrderGroups, 1)
        let enforceGroupModelOrder = shouldEnforceGroupModelOrder(layeredGraph)

        let calculator = GroupModelOrderCalculator()
        for source in layerlessNodes {
            let modelOrderSource = enforceGroupModelOrder
                ? calculator.computeConstraintGroupModelOrder(source, bigOffset, offset)
                : calculator.computeConstraintModelOrder(source, offset)

            for port in source.getPorts(.OUTPUT) {
                for edge in port.getOutgoingEdges() {
                    guard let target = edge.getTarget()?.getNode() else {
                        continue
                    }
                    let modelOrderTarget = enforceGroupModelOrder
                        ? calculator.computeConstraintGroupModelOrder(target, bigOffset, offset)
                        : calculator.computeConstraintModelOrder(target, offset)
                    if modelOrderTarget < modelOrderSource {
                        revEdges.append(edge)
                    }
                }
            }
        }

        for edge in revEdges {
            reverseEdge(edge, in: layeredGraph)
            layeredGraph.setProperty(InternalProperties.CYCLIC, true)
        }
        revEdges.removeAll(keepingCapacity: false)
    }

    package func shouldEnforceGroupModelOrder(
        _ layeredGraph: LGraph
    ) -> Bool {
        ModelOrderPropertyScaffolding
            .groupOrderStrategy(for: layeredGraph) == .ENFORCED
    }

    package func reverseEdge(
        _ edge: LEdge,
        in layeredGraph: LGraph
    ) {
        edge.reverse(layeredGraph, true)
    }
}
