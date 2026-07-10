// Ported from elk-source/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p3order/counting/CrossMinUtil.java
import Foundation

package final class CrossMinUtil {
    private init() {}

    package static func inNorthSouthEastWestOrder(
        _ node: LNode,
        _ side: PortSide
    ) -> [LPort] {
        switch side {
        case .EAST, .NORTH:
            return Array(node.getPortSideView(side))
        case .SOUTH, .WEST:
            return node.getPortSideView(side).reversed()
        default:
            return []
        }
    }
}
