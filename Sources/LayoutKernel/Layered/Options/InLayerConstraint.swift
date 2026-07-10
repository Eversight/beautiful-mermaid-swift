// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/InLayerConstraint.java

import Foundation

/// Enumeration of in-layer constraint types.
package enum InLayerConstraint {
    /// No constraint on in-layer placement.
    case NONE

    /// Float node to the top of the layer, along with other nodes with this constraint.
    case TOP

    /// Float node to the bottom of the layer, along with other nodes with this constraint.
    case BOTTOM
}
