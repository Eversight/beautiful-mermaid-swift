// Ported from elk-source/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p4nodes/SimpleNodePlacer.java
import Foundation

package final class SimpleNodePlacer {
    /// Additional processor dependencies for graphs with hierarchical ports.
    package static let HIERARCHY_PROCESSING_ADDITIONS: LayoutProcessorConfiguration<LayeredPhases, LGraph> = {
        LayoutProcessorConfiguration<LayeredPhases, LGraph>.create()
            .addBefore(
                LayeredPhases.P5_EDGE_ROUTING,
                IntermediateProcessorStrategy.HIERARCHICAL_PORT_POSITION_PROCESSOR
            )
    }()

    package init() {}

    package func getLayoutProcessorConfiguration(
        _ graph: LGraph
    ) -> LayoutProcessorConfiguration<LayeredPhases, LGraph>? {
        let graphProperties = graph.getProperty(InternalProperties.GRAPH_PROPERTIES)
            as? Set<GraphProperties> ?? []
        if graphProperties.contains(.EXTERNAL_PORTS) {
            return Self.HIERARCHY_PROCESSING_ADDITIONS
        }
        return nil
    }

    package func process(
        _ layeredGraph: LGraph,
        _ monitor: any IElkProgressMonitor
    ) {
        monitor.begin("Simple node placement", 1)

        let spacings = layeredGraph.getProperty(InternalProperties.SPACINGS)
            as? Spacings ?? Spacings()

        // First iteration: determine the height of each layer.
        var maxHeight: Double = 0.0
        for layer in layeredGraph.getLayers() {
            let layerSize = layer.getSize()
            layerSize.y = 0.0

            var lastNode: LNode?
            for node in layer.getNodes() {
                if let lastNode {
                    layerSize.y += spacings.getVerticalSpacing(node, lastNode)
                }
                layerSize.y += node.getMargin().top + node.getSize().y + node.getMargin().bottom
                lastNode = node
            }

            maxHeight = Swift.max(maxHeight, layerSize.y)
        }

        // Second iteration: center nodes of each layer around the tallest layer.
        for layer in layeredGraph.getLayers() {
            let layerSize = layer.getSize()
            var pos = (maxHeight - layerSize.y) / 2.0

            var lastNode: LNode?
            for node in layer.getNodes() {
                if let lastNode {
                    pos += spacings.getVerticalSpacing(node, lastNode)
                }
                pos += node.getMargin().top
                node.getPosition().y = pos
                pos += node.getSize().y + node.getMargin().bottom
                lastNode = node
            }
        }

        monitor.done()
    }
}
