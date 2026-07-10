// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/NodePlacementStrategy.java

import Foundation

package enum NodePlacementStrategy: ILayoutPhaseFactory {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph

    case SIMPLE
    case INTERACTIVE
    case LINEAR_SEGMENTS
    case BRANDES_KOEPF
    case NETWORK_SIMPLEX

    package func create() -> any ILayoutPhase {
        switch self {
        case .SIMPLE:
            return SimpleNodePlacer()
        case .INTERACTIVE:
            return InteractiveNodePlacer()
        case .LINEAR_SEGMENTS:
            return LinearSegmentsNodePlacer()
        case .BRANDES_KOEPF:
            return BKNodePlacer()
        case .NETWORK_SIMPLEX:
            return NetworkSimplexPlacer()
        }
    }
}

extension SimpleNodePlacer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
extension InteractiveNodePlacer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
extension LinearSegmentsNodePlacer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
extension BKNodePlacer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
extension NetworkSimplexPlacer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
