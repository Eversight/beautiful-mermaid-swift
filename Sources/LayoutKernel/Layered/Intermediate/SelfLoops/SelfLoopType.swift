// Ported from the Eclipse Layout Kernel (Java). This Swift source has
// diverged from the original and is authoritative.

// Java source: plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/intermediate/loops/SelfLoopType.java

import Foundation

package enum SelfLoopType {
    case ONE_SIDE
    case TWO_SIDES_CORNER
    case TWO_SIDES_OPPOSING
    case THREE_SIDES
    case FOUR_SIDES

    package static func fromPortSides(
        _ portSides: Set<PortSide>
    ) -> SelfLoopType? {
        if portSides.contains(.UNDEFINED) {
            assertionFailure("Port sides must not contain UNDEFINED")
            return nil
        }

        switch portSides.count {
        case 1:
            return .ONE_SIDE

        case 2:
            let eastWest = portSides.contains(.EAST) && portSides.contains(.WEST)
            let northSouth = portSides.contains(.NORTH) && portSides.contains(.SOUTH)
            return (eastWest || northSouth) ? .TWO_SIDES_OPPOSING : .TWO_SIDES_CORNER

        case 3:
            return .THREE_SIDES

        case 4:
            return .FOUR_SIDES

        default:
            return nil
        }
    }
}
