// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/InteractiveReferencePoint.java

import Foundation

/// Reference point used by interactive layout phases for node position comparison.
package enum InteractiveReferencePoint {
    /// The node's center point.
    case CENTER

    /// The node's top left corner.
    case TOP_LEFT
}
