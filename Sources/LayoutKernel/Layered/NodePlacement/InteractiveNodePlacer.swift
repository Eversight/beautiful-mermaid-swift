// Ported from elk-source/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p4nodes/InteractiveNodePlacer.java
import Foundation

package final class InteractiveNodePlacer {
    /// Additional processor dependencies for graphs with hierarchical ports.
    package static let HIERARCHY_PROCESSING_ADDITIONS: LayoutProcessorConfiguration<LayeredPhases, LGraph> = {
        LayoutProcessorConfiguration<LayeredPhases, LGraph>.create()
            .addBefore(
                LayeredPhases.P5_EDGE_ROUTING,
                IntermediateProcessorStrategy.HIERARCHICAL_PORT_POSITION_PROCESSOR
            )
    }()

    /// Spacing values.
    package var spacings: Spacings?

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
        monitor.begin("Interactive node placement", 1)

        spacings = layeredGraph.getProperty(InternalProperties.SPACINGS)
            as? Spacings ?? Spacings()

        // Place the nodes in each layer.
        for layer in layeredGraph {
            placeNodes(layer)
        }

        // Java source also leaves graph-offset computation unimplemented at this stage.

        monitor.done()
    }

    /// Places the nodes in the given layer.
    package func placeNodes(_ layer: Layer) {
        let spacings = self.spacings ?? Spacings()

        // The minimum value for the next valid y coordinate.
        var minValidY = -Double.infinity

        // The node type of the last node.
        var prevNodeType: NodeType = .NORMAL

        for node in layer {
            let nodeType = node.getType()

            if nodeType != .NORMAL {
                // While normal nodes keep their original position, dummy nodes may need reconstruction.
                let originalYCoordinate = node.getProperty(
                    InternalProperties.ORIGINAL_DUMMY_NODE_POSITION
                ) as? Double

                if let originalYCoordinate {
                    node.getPosition().y = originalYCoordinate
                } else {
                    // Make sure that the minimum valid Y position is usable.
                    minValidY = Swift.max(minValidY, 0.0)
                    node.getPosition().y = minValidY + spacings.getVerticalSpacing(nodeType, prevNodeType)
                }
            }

            // If the node overlaps previously placed nodes, move it down.
            let spacing = spacings.getVerticalSpacing(nodeType, prevNodeType)
            if node.getPosition().y < minValidY + spacing + node.getMargin().top {
                node.getPosition().y = minValidY + spacing + node.getMargin().top
            }

            // Update minimum valid y coordinate and remember node type.
            minValidY = node.getPosition().y + node.getSize().y + node.getMargin().bottom
            prevNodeType = nodeType
        }
    }
}
