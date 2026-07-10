// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/LayerUnzippingStrategy.java

import Foundation

/// Strategies for unzipping layers by splitting nodes into multiple layers.
package enum LayerUnzippingStrategy {
    /// Disable layer unzipping.
    case NONE

    /// Split all layers with more than two nodes into several layers in an alternating pattern.
    case ALTERNATING
}
