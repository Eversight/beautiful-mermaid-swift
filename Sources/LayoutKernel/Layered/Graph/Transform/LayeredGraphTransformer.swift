import Foundation

/**
 * Manages the transformation of ELK Graphs to LayeredGraphs. Sets the
 * {@link org.eclipse.elk.alg.layered.options.LayeredOptions#GRAPH_PROPERTIES GRAPH_PROPERTIES}
 * property on imported graphs.
 * 
 * @author msp
 * @author cds
 * @see LayeredGraphImporter
 * @see GraphLayoutTransferrer
 */
package final class LayeredGraphTransformer: IGraphTransformer {

    package func importGraph(_ graph: Any) throws -> LGraph? {
        guard let elkNode = graph as? GraphNode else { return nil }
        return try LayeredGraphImporter().importGraph(elkNode)
    }
    
    package func applyLayout(_ layeredGraph: LGraph) {
        GraphLayoutTransferrer().apply(layeredGraph)
    }
    
    // Utility
    
    /**
     * Returns an identifier string for the original LayoutGraphProtocol element.
     * 
     * @param element an LGraph element
     * @return the original identifier, or `nil` if none is defined
     */
    package static func getOriginIdentifier(_ element: LGraphElement) -> String? {
        guard let origin = element.getProperty(InternalProperties.ORIGIN) as? (any GraphElement) else {
            return nil
        }
        return getIdentifier(origin)
    }
    
    package static func getIdentifier(_ element: any GraphElement) -> String? {
        guard let id = element.identifier, !id.isEmpty else {
            return nil
        }

        // In the full ELK implementation, this would walk up the EMF containment hierarchy.
        // Since graph/impl is excluded, we just return the element's own identifier.

        return id
    }
}
