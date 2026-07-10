// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/GreedySwitchType.java

import Foundation

/// Sets the variant of the greedy switch heuristic.
package enum GreedySwitchType {
    /// Only consider crossings to one side of the free layer.
    /// Calculate crossing matrix on demand.
    case ONE_SIDED

    /// Consider crossings to both sides of the free layer.
    /// Calculate crossing matrix on demand.
    case TWO_SIDED

    /// Do not use greedy switch.
    case OFF
}
