// Ported from elk-source WestToEastRoutingStrategy.java

import Foundation

package final class WestToEastRoutingStrategy: BaseRoutingDirectionStrategy {

    override package func getPortPositionOnHyperNode(_ port: LPort) -> Double {
        guard let node = port.getNode() else { return 0 }
        return node.getPosition().y + port.getPosition().y + port.getAnchor().y
    }

    override package func getSourcePortSide() -> PortSide {
        return .EAST
    }

    override package func getTargetPortSide() -> PortSide {
        return .WEST
    }

    override package func calculateBendPoints(
        _ segment: HyperEdgeSegment,
        _ startPos: Double,
        _ edgeSpacing: Double
    ) {
        // We don't do anything with dummy segments; they are dealt with when their partner is processed
        if segment.isDummy() {
            return
        }

        // Calculate coordinates for each port's bend points
        let segmentX = startPos + Double(segment.getRoutingSlot()) * edgeSpacing

        for port in segment.getPorts() {
            let sourceY = port.getAbsoluteAnchor().y

            for edge in port.getOutgoingEdges() {
                if !edge.isSelfLoop() {
                    guard let target = edge.getTarget() else { continue }
                    let targetY = target.getAbsoluteAnchor().y

                    if abs(sourceY - targetY) > OrthogonalRoutingGenerator.TOLERANCE {
                        // We'll update these if we find that the segment was split
                        var currentX = segmentX
                        var currentSegment = segment

                        var bend = KVector(currentX, sourceY)
                        edge.getBendPoints().add(bend)
                        addJunctionPointIfNecessary(edge, currentSegment, bend, true)

                        // If this segment was split, we need two additional bend points
                        if let splitPartner = segment.getSplitPartner() {
                            let splitY = splitPartner.getIncomingConnectionCoordinates()[0]

                            bend = KVector(currentX, splitY)
                            edge.getBendPoints().add(bend)
                            addJunctionPointIfNecessary(edge, currentSegment, bend, true)

                            // Advance to the split partner's routing slot
                            currentX = startPos + Double(splitPartner.getRoutingSlot()) * edgeSpacing
                            currentSegment = splitPartner

                            bend = KVector(currentX, splitY)
                            edge.getBendPoints().add(bend)
                            addJunctionPointIfNecessary(edge, currentSegment, bend, true)
                        }

                        bend = KVector(currentX, targetY)
                        edge.getBendPoints().add(bend)
                        addJunctionPointIfNecessary(edge, currentSegment, bend, true)
                    }
                }
            }
        }
    }
}
