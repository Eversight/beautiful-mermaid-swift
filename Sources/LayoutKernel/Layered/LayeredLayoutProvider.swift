import Foundation

/**
 * Layout provider to connect the layered layouter to the Eclipse based layout services.
 *
 * @see LayeredAlgorithm
 */
package final class LayeredLayoutProvider: AbstractLayoutProvider {

    // MARK: - Variables

    /** the layout algorithm used for regular layout runs. */
    package let elkLayered = LayeredAlgorithm()


    // MARK: - Regular Layout

    package override func layout(layoutGraph elkgraph: GraphNode, progressMonitor: IElkProgressMonitor) throws {
        // Import the graph
        let graphTransformer = LayeredGraphTransformer()
        guard let layeredGraph = try graphTransformer.importGraph(elkgraph) else { return }
        // The LGraph is transient: once the layout has been applied back to
        // the GraphNode graph it must be torn down, or its internal reference
        // cycles leak the whole graph (the Java original relies on GC).
        defer { layeredGraph.tearDown() }

        // Check if hierarchy handling for a compound graph is requested
        let hierHandling = elkgraph.getProperty(LayeredOptions.HIERARCHY_HANDLING) as? HierarchyHandling
        if hierHandling == HierarchyHandling.INCLUDE_CHILDREN {
            elkLayered.doCompoundLayout(layeredGraph, progressMonitor)
        } else {
            elkLayered.doLayout(layeredGraph, progressMonitor)
        }

        if !progressMonitor.isCanceled() {
            graphTransformer.applyLayout(layeredGraph)
        }
    }


    // MARK: - Layout Testing

    package func startLayoutTest(_ elkgraph: GraphNode) throws -> LayeredAlgorithm.TestExecutionState {
        let graphImporter = LayeredGraphTransformer()
        let layeredGraph = try graphImporter.importGraph(elkgraph)
        guard let layeredGraph = layeredGraph else {
            return elkLayered.prepareLayoutTest(LGraph())
        }

        return elkLayered.prepareLayoutTest(layeredGraph)
    }

    package func getLayoutAlgorithm() -> LayeredAlgorithm {
        return elkLayered
    }

    package func setTestController(_ controller: TestController?) {
        elkLayered.setTestController(controller)
    }
}
