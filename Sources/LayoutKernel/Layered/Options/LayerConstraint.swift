// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/LayerConstraint.java

import Foundation

/// Enumeration of layer constraint types.
package enum LayerConstraint {
    /// No constraint on the layering.
    case NONE

    /// Put into the first layer.
    case FIRST

    /// Put into a separate first layer; used internally.
    case FIRST_SEPARATE

    /// Put into the last layer.
    case LAST

    /// Put into a separate last layer; used internally.
    case LAST_SEPARATE
}
