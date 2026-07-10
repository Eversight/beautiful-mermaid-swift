// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p2layers/BreadthFirstModelOrderLayerer.java

import Foundation

package final class BreadthFirstModelOrderLayerer {
    package var layeredGraph: LGraph?

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
        monitor.begin("Breadth first model order layering", 1)

        layeredGraph = thelayeredGraph

        let layerlessNodes = thelayeredGraph.getLayerlessNodes()
        var realNodes = layerlessNodes.filter { $0.getType() == .NORMAL }

        realNodes.sort {
            let leftModelOrder = ModelOrderPropertyScaffolding
                .modelOrder(for: $0) ?? $0.id
            let rightModelOrder = ModelOrderPropertyScaffolding
                .modelOrder(for: $1) ?? $1.id
            if leftModelOrder == rightModelOrder {
                return $0.id < $1.id
            }
            return leftModelOrder < rightModelOrder
        }

        var firstNode = true
        var currentLayer = thelayeredGraph.addLayer()
        var currentDummyLayer: Layer?

        for node in realNodes {
            if firstNode {
                node.setLayer(currentLayer)
                firstNode = false
            } else {
                for edge in node.getIncomingEdges() {
                    guard let sourceNode = edge.getSource()?.getNode() else {
                        continue
                    }

                    var isConnectedToCurrentLayer = false
                    if sourceNode.getType() == .NORMAL {
                        isConnectedToCurrentLayer = sourceNode.getLayer() === currentLayer
                    } else if sourceNode.getType() == .LABEL {
                        if let firstIncomingEdge = sourceNode.getIncomingEdges().first,
                           let labelSourceNode = firstIncomingEdge.getSource()?.getNode() {
                            isConnectedToCurrentLayer = labelSourceNode.getLayer() === currentLayer
                        }
                    }

                    if isConnectedToCurrentLayer {
                        currentDummyLayer = thelayeredGraph.addLayer()
                        currentLayer = thelayeredGraph.addLayer()
                    }
                }

                for edge in node.getIncomingEdges() {
                    guard let sourceNode = edge.getSource()?.getNode() else {
                        continue
                    }
                    if sourceNode.getType() == .LABEL && sourceNode.getLayer() == nil {
                        sourceNode.setLayer(currentDummyLayer)
                    }
                }

                node.setLayer(currentLayer)
            }
        }

        for node in layerlessNodes {
            thelayeredGraph.removeLayerlessNode(node)
        }

        let layersSnapshot = thelayeredGraph.getLayers()
        let emptyLayers = layersSnapshot.filter { $0.getNodes().isEmpty }
        for layer in emptyLayers {
            thelayeredGraph.removeLayer(layer)
        }

        for (layerId, layer) in thelayeredGraph.getLayers().enumerated() {
            layer.id = layerId
        }

        layeredGraph = nil
        monitor.done()
    }
}
