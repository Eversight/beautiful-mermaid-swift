// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p5edges/EdgeRouterFactory.java

import Foundation

package enum EdgeRouterFactory: ILayoutPhaseFactory {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph

    case POLYLINE
    case ORTHOGONAL
    case SPLINES

    package func create() -> any ILayoutPhase {
        switch self {
        case .POLYLINE:
            return PolylineEdgeRouter()
        case .ORTHOGONAL:
            return OrthogonalEdgeRouter()
        case .SPLINES:
            assertionFailure("Spline routing is not supported")
            return OrthogonalEdgeRouter()
        }
    }

    package static func factoryFor(_ edgeRouting: EdgeRouting) -> EdgeRouterFactory {
        switch edgeRouting {
        case .POLYLINE:
            return .POLYLINE
        case .ORTHOGONAL:
            return .ORTHOGONAL
        case .SPLINES:
            return .SPLINES
        default:
            return .ORTHOGONAL
        }
    }
}

extension PolylineEdgeRouter: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
extension OrthogonalEdgeRouter: ILayoutPhase {
    package typealias P = LayeredPhases
    package typealias PhaseGraph = LGraph
    package typealias G = LGraph
}
// REMOVED: SplineEdgeRouter extension (splines dead code)
