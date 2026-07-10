// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/CycleBreakingStrategy.java

import Foundation

package enum CycleBreakingStrategy: ILayoutPhaseFactory {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph

    case GREEDY
    case DEPTH_FIRST
    case INTERACTIVE
    case MODEL_ORDER
    case GREEDY_MODEL_ORDER
    case SCC_CONNECTIVITY
    case SCC_NODE_TYPE
    case DFS_NODE_ORDER
    case BFS_NODE_ORDER

    package func create() -> any ILayoutPhase {
        switch self {
        case .GREEDY:
            return GreedyCycleBreaker()
        case .DEPTH_FIRST:
            return DepthFirstCycleBreaker()
        case .INTERACTIVE:
            return InteractiveCycleBreaker()
        case .MODEL_ORDER:
            return ModelOrderCycleBreaker()
        case .GREEDY_MODEL_ORDER:
            return GreedyModelOrderCycleBreaker()
        case .SCC_CONNECTIVITY:
            return SCConnectivity()
        case .SCC_NODE_TYPE:
            return SCCNodeTypeCycleBreaker()
        case .DFS_NODE_ORDER:
            return DFSNodeOrderCycleBreaker()
        case .BFS_NODE_ORDER:
            return BFSNodeOrderCycleBreaker()
        }
    }
}

extension GreedyCycleBreaker: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
extension DepthFirstCycleBreaker: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
extension InteractiveCycleBreaker: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
extension ModelOrderCycleBreaker: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
// GreedyModelOrderCycleBreaker inherits ILayoutPhase from GreedyCycleBreaker
extension SCCModelOrderCycleBreaker: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
// SCConnectivity and SCCNodeTypeCycleBreaker inherit ILayoutPhase from SCCModelOrderCycleBreaker
extension DFSNodeOrderCycleBreaker: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
extension BFSNodeOrderCycleBreaker: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
