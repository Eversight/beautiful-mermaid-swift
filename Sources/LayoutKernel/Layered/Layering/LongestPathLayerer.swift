// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p2layers/LongestPathLayerer.java

import Foundation

package final class LongestPathLayerer {
    package var layeredGraph: LGraph?
    package var nodeHeights: [Int] = []

    package init() {}

    package func getLayoutProcessorConfiguration(
        _ graph: LGraph
    ) -> LayoutProcessorConfiguration<LayeredPhases, LGraph>? {
        _ = graph
        return LayoutProcessorConfiguration<LayeredPhases, LGraph>.create()
            .addBefore(
                LayeredPhases.P1_CYCLE_BREAKING,
                IntermediateProcessorStrategy
                    .EDGE_AND_LAYER_CONSTRAINT_EDGE_REVERSER
            )
            .addBefore(
                LayeredPhases.P2_LAYERING,
                IntermediateProcessorStrategy
                    .LAYER_CONSTRAINT_PREPROCESSOR
            )
            .addBefore(
                LayeredPhases.P3_NODE_ORDERING,
                IntermediateProcessorStrategy
                    .LAYER_CONSTRAINT_POSTPROCESSOR
            )
    }

    package func process(
        _ thelayeredGraph: LGraph,
        _ monitor: any IElkProgressMonitor
    ) {
        monitor.begin("Longest path layering", 1)

        layeredGraph = thelayeredGraph
        let nodes = thelayeredGraph.getLayerlessNodes()

        nodeHeights = Array(repeating: -1, count: nodes.count)
        for (index, node) in nodes.enumerated() {
            node.id = index
            nodeHeights[index] = -1
        }

        for node in nodes {
            _ = visit(node)
        }

        let maxHeight = nodeHeights.max() ?? 0
        if maxHeight > 0 {
            var layers: [Layer] = []
            layers.reserveCapacity(maxHeight)
            for _ in 0..<maxHeight {
                let layer = thelayeredGraph.addLayer()
                layers.append(layer)
            }

            for node in nodes {
                let height = nodeHeights[node.id]
                if height > 0 {
                    node.setLayer(layers[maxHeight - height])
                }
            }
        }

        for node in nodes {
            thelayeredGraph.removeLayerlessNode(node)
        }

        layeredGraph = nil
        nodeHeights = []
        monitor.done()
    }

    package func visit(_ node: LNode) -> Int {
        let cachedHeight = nodeHeights[node.id]
        if cachedHeight >= 0 {
            return cachedHeight
        }

        var maxHeight = 1
        for port in node.getPorts() {
            for edge in port.getOutgoingEdges() {
                guard let targetNode = edge.getTarget()?.getNode() else {
                    continue
                }

                if node !== targetNode {
                    let targetHeight = visit(targetNode)
                    maxHeight = max(maxHeight, targetHeight + 1)
                }
            }
        }

        nodeHeights[node.id] = maxHeight
        return maxHeight
    }
}
