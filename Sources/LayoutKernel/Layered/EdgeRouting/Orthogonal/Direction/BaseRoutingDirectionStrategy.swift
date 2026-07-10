// Ported from elk-source/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p5edges/orthogonal/direction/BaseRoutingDirectionStrategy.java

import Foundation

package class BaseRoutingDirectionStrategy {

    package static let JUNCTION_POINTS_KEY: any IProperty = Property<KVectorChain>("org.eclipse.elk.junctionPoints")

    /// set of already created junction points, to avoid multiple points at the same position.
    package var createdJunctionPoints: Set<KVector> = []

    package init() {}

    // MARK: - Factory

    /// Returns an implementation suitable for the given routing direction.
    package static func forRoutingDirection(
        _ direction: RoutingDirection
    ) -> BaseRoutingDirectionStrategy {
        switch direction {
        case .WEST_TO_EAST:
            return WestToEastRoutingStrategy()
        case .NORTH_TO_SOUTH:
            return NorthToSouthRoutingStrategy()
        case .SOUTH_TO_NORTH:
            return SouthToNorthRoutingStrategy()
        }
    }

    // MARK: - Junction Points

    /// Add a junction point to the given edge if necessary.
    package func addJunctionPointIfNecessary(
        _ edge: LEdge,
        _ segment: HyperEdgeSegment,
        _ pos: KVector,
        _ vertical: Bool
    ) {
        let p = vertical ? pos.y : pos.x

        // If we already have this junction point, don't bother
        if createdJunctionPoints.contains(pos) {
            return
        }

        // Whether the point lies somewhere inside the edge segment (without boundaries)
        let pointInsideEdgeSegment = p > segment.getStartCoordinate() && p < segment.getEndCoordinate()

        // Check if the point lies somewhere at the segment's boundary
        var pointAtSegmentBoundary = false
        let inCoords = segment.getIncomingConnectionCoordinates()
        let outCoords = segment.getOutgoingConnectionCoordinates()
        if let inFirst = inCoords.first, let outFirst = outCoords.first,
           let inLast = inCoords.last, let outLast = outCoords.last {

            // Is the bend point at the start and joins another edge at the same position?
            pointAtSegmentBoundary = pointAtSegmentBoundary
                || (abs(p - inFirst)
                    < OrthogonalRoutingGenerator.TOLERANCE
                    && abs(p - outFirst)
                        < OrthogonalRoutingGenerator.TOLERANCE)

            // Is the bend point at the end and joins another edge at the same position?
            pointAtSegmentBoundary = pointAtSegmentBoundary
                || (abs(p - inLast)
                    < OrthogonalRoutingGenerator.TOLERANCE
                    && abs(p - outLast)
                        < OrthogonalRoutingGenerator.TOLERANCE)
        }

        if pointInsideEdgeSegment || pointAtSegmentBoundary {
            // create a new junction point for the edge at the bend point's position
            var junctionPoints: KVectorChain
            if let existing: KVectorChain = edge.getProperty(BaseRoutingDirectionStrategy.JUNCTION_POINTS_KEY) {
                junctionPoints = existing
            } else {
                junctionPoints = KVectorChain()
                edge.setProperty(BaseRoutingDirectionStrategy.JUNCTION_POINTS_KEY, junctionPoints)
            }

            let jpoint = KVector(pos)
            junctionPoints.add(jpoint)
            createdJunctionPoints.insert(jpoint)
        }
    }

    /// Removes all junction points created so far.
    package func clearCreatedJunctionPoints() {
        createdJunctionPoints.removeAll()
    }

    /// Returns the set of junction points created so far.
    package func getCreatedJunctionPoints() -> Set<KVector> {
        return createdJunctionPoints
    }

    // MARK: - Abstract methods (to be overridden by subclasses)

    /// Returns the port's position on a hyper edge axis.
    package func getPortPositionOnHyperNode(_ port: LPort) -> Double {
        assertionFailure("Subclass must override getPortPositionOnHyperNode")
        return 0
    }

    /// Returns the side of ports that should be considered on a source layer.
    package func getSourcePortSide() -> PortSide {
        assertionFailure("Subclass must override getSourcePortSide")
        return .UNDEFINED
    }

    /// Returns the side of ports that should be considered on a target layer.
    package func getTargetPortSide() -> PortSide {
        assertionFailure("Subclass must override getTargetPortSide")
        return .UNDEFINED
    }

    /// Calculates and assigns bend points for edges incident to the ports belonging to the given hyper edge.
    package func calculateBendPoints(
        _ hyperNode: HyperEdgeSegment,
        _ startPos: Double,
        _ edgeSpacing: Double
    ) {
        assertionFailure("Subclass must override calculateBendPoints")
    }
}
