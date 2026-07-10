// Ported from elk-source/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/options/PortType.java
import Foundation

/// Definition of port types.
package enum PortType {
    /// Undefined port type.
    case UNDEFINED
    /// Input port type.
    case INPUT
    /// Output port type.
    case OUTPUT

    // MARK: - Lowercase Aliases (Swift convention)
    package static let input = PortType.INPUT
    package static let output = PortType.OUTPUT
    package static let undefined = PortType.UNDEFINED
}
