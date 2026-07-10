// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p3order/NoCrossingMinimizer.java

import Foundation

package final class NoCrossingMinimizer {
    // Java: private static final LayoutProcessorConfiguration<LayeredPhases, LGraph> INTERMEDIATE_PROCESSING_CONFIGURATION
    package static let INTERMEDIATE_PROCESSING_CONFIGURATION: LayoutProcessorConfiguration<LayeredPhases, LGraph> =
        LayoutProcessorConfiguration<LayeredPhases, LGraph>.create()
            .addBefore(
                LayeredPhases.P3_NODE_ORDERING,
                IntermediateProcessorStrategy.LONG_EDGE_SPLITTER
            )
            .addBefore(
                LayeredPhases.P4_NODE_PLACEMENT,
                IntermediateProcessorStrategy.IN_LAYER_CONSTRAINT_PROCESSOR
            )
            .addAfter(
                LayeredPhases.P5_EDGE_ROUTING,
                IntermediateProcessorStrategy.LONG_EDGE_JOINER
            )

    package init() {}

    package func process(
        _ graph: LGraph,
        _ progressMonitor: any IElkProgressMonitor
    ) {
        progressMonitor.begin("No crossing minimization", 1)
        progressMonitor.done()
    }

    package func getLayoutProcessorConfiguration(
        _ graph: LGraph
    ) -> LayoutProcessorConfiguration<LayeredPhases, LGraph>? {
        let configuration = LayoutProcessorConfiguration<LayeredPhases, LGraph>.create(
            from: Self.INTERMEDIATE_PROCESSING_CONFIGURATION
        )

        configuration.addBefore(
            LayeredPhases.P3_NODE_ORDERING,
            IntermediateProcessorStrategy.PORT_LIST_SORTER
        )
        return configuration
    }
}
