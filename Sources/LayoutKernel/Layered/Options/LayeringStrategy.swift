// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/LayeringStrategy.java

import Foundation

package enum LayeringStrategy: ILayoutPhaseFactory {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph

    /// All nodes will be layered with minimal edge length by using the network-simplex algorithm.
    case NETWORK_SIMPLEX

    /// All nodes will be layered according to the longest path to any sink.
    case LONGEST_PATH

    /// All nodes will be layered according to the longest path to any source.
    case LONGEST_PATH_SOURCE

    /// Restricts the number of original nodes in any layer.
    case COFFMAN_GRAHAM

    /// Layers according to relative node positions from input.
    case INTERACTIVE

    /// Similar to LONGEST_PATH, but tries to reduce max nodes per layer.
    case STRETCH_WIDTH

    /// MinWidth heuristic for minimum-width layering with dummy-node awareness.
    case MIN_WIDTH

    /// Breadth-first model-order-driven layering.
    case BF_MODEL_ORDER

    /// Depth-first model-order-driven layering.
    case DF_MODEL_ORDER

    package func create() -> any ILayoutPhase {
        switch self {
        case .NETWORK_SIMPLEX:
            return NetworkSimplexLayerer()
        case .LONGEST_PATH:
            return LongestPathLayerer()
        case .COFFMAN_GRAHAM:
            return CoffmanGrahamLayerer()
        case .INTERACTIVE:
            return InteractiveLayerer()
        case .STRETCH_WIDTH:
            return StretchWidthLayerer()
        case .MIN_WIDTH:
            return MinWidthLayerer()
        case .LONGEST_PATH_SOURCE:
            return LongestPathSourceLayerer()
        case .BF_MODEL_ORDER:
            return BreadthFirstModelOrderLayerer()
        case .DF_MODEL_ORDER:
            return DepthFirstModelOrderLayerer()
        }
    }
}

// Classes that already have process() and getLayoutProcessorConfiguration() defined
extension LongestPathLayerer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
extension InteractiveLayerer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
extension LongestPathSourceLayerer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
extension BreadthFirstModelOrderLayerer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}

extension NetworkSimplexLayerer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
extension CoffmanGrahamLayerer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
    package func getLayoutProcessorConfiguration(_ graph: LGraph) -> LayoutProcessorConfiguration<LayeredPhases, LGraph>? { nil }
}
extension StretchWidthLayerer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
    package func getLayoutProcessorConfiguration(_ graph: LGraph) -> LayoutProcessorConfiguration<LayeredPhases, LGraph>? { nil }
}
extension MinWidthLayerer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
    package func getLayoutProcessorConfiguration(_ graph: LGraph) -> LayoutProcessorConfiguration<LayeredPhases, LGraph>? { nil }
}
extension DepthFirstModelOrderLayerer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
    package func process(_ graph: LGraph, _ progressMonitor: IElkProgressMonitor) {}
    package func getLayoutProcessorConfiguration(_ graph: LGraph) -> LayoutProcessorConfiguration<LayeredPhases, LGraph>? { nil }
}
