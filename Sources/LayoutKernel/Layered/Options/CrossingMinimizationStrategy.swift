// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/CrossingMinimizationStrategy.java

import Foundation

package enum CrossingMinimizationStrategy: ILayoutPhaseFactory {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph

    case LAYER_SWEEP
    case MEDIAN_LAYER_SWEEP
    case INTERACTIVE
    case NONE

    package func create() -> any ILayoutPhase {
        switch self {
        case .LAYER_SWEEP:
            return LayerSweepCrossingMinimizer(.BARYCENTER)
        case .MEDIAN_LAYER_SWEEP:
            return LayerSweepCrossingMinimizer(.MEDIAN)
        case .INTERACTIVE:
            return InteractiveCrossingMinimizer()
        case .NONE:
            return NoCrossingMinimizer()
        }
    }
}

extension LayerSweepCrossingMinimizer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
extension InteractiveCrossingMinimizer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
extension NoCrossingMinimizer: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
