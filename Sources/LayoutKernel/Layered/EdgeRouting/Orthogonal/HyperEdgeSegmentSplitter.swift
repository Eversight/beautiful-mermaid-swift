// Ported from elk-source/plugins/org.eclipse.elk.alg.layered/src/org/eclipse/elk/alg/layered/p5edges/orthogonal/HyperEdgeSegmentSplitter.java
import Foundation

package final class HyperEdgeSegmentSplitter {
    package var routingGenerator: OrthogonalRoutingGenerator?

    package init() {}

    package init(_ routingGenerator: OrthogonalRoutingGenerator) {
        self.routingGenerator = routingGenerator
    }

    package func splitSegments(
        _ dependenciesToResolve: [HyperEdgeSegmentDependency],
        _ segments: [HyperEdgeSegment],
        _ criticalConflictThreshold: Double
    ) {
        var mutableSegments = segments
        splitSegments(dependenciesToResolve, &mutableSegments, criticalConflictThreshold)
    }

    package func splitSegments(
        _ dependenciesToResolve: [HyperEdgeSegmentDependency],
        _ segments: inout [HyperEdgeSegment],
        _ criticalConflictThreshold: Double
    ) {
        if dependenciesToResolve.isEmpty {
            return
        }

        var freeAreas = findFreeAreas(segments, criticalConflictThreshold)
        let segmentsToSplit = decideWhichSegmentsToSplit(dependenciesToResolve)

        for segment in segmentsToSplit.sorted(by: { $0.getLength() < $1.getLength() }) {
            split(segment, &segments, &freeAreas, criticalConflictThreshold)
        }
    }

    package func findFreeAreas(
        _ segments: [HyperEdgeSegment],
        _ criticalConflictThreshold: Double
    ) -> [FreeArea] {
        var freeAreas: [FreeArea] = []
        var coordinates: [Double] = []

        for segment in segments {
            coordinates.append(contentsOf: segment.getIncomingConnectionCoordinates())
            coordinates.append(contentsOf: segment.getOutgoingConnectionCoordinates())
        }

        coordinates.sort()

        guard coordinates.count >= 2 else {
            return freeAreas
        }

        for i in 1..<coordinates.count {
            if coordinates[i] - coordinates[i - 1] >= 2.0 * criticalConflictThreshold {
                freeAreas.append(
                    FreeArea(
                        coordinates[i - 1] + criticalConflictThreshold,
                        coordinates[i] - criticalConflictThreshold
                    )
                )
            }
        }

        return freeAreas
    }

    package func decideWhichSegmentsToSplit(
        _ dependencies: [HyperEdgeSegmentDependency]
    ) -> [HyperEdgeSegment] {
        var segmentsToSplit: [HyperEdgeSegment] = []
        var selected: Set<ObjectIdentifier> = []

        for dependency in dependencies {
            guard let sourceSegment = dependency.getSource(),
                  let targetSegment = dependency.getTarget() else { continue }

            if selected.contains(ObjectIdentifier(sourceSegment))
                || selected.contains(ObjectIdentifier(targetSegment)) {
                continue
            }

            var segmentToSplit = sourceSegment
            var segmentCausingSplit = targetSegment

            if sourceSegment.representsHyperedge() && !targetSegment.representsHyperedge() {
                segmentToSplit = targetSegment
                segmentCausingSplit = sourceSegment
            }

            segmentsToSplit.append(segmentToSplit)
            selected.insert(ObjectIdentifier(segmentToSplit))
            segmentToSplit.setSplitBy(segmentCausingSplit)
        }

        return segmentsToSplit
    }

    package func split(
        _ segment: HyperEdgeSegment,
        _ segments: inout [HyperEdgeSegment],
        _ freeAreas: inout [FreeArea],
        _ criticalConflictThreshold: Double
    ) {
        let splitPosition = computePositionToSplitAndUpdateFreeAreas(segment, &freeAreas, criticalConflictThreshold)
        segments.append(segment.splitAt(splitPosition))
        updateDependencies(segment, segments)
    }

    package func updateDependencies(
        _ segment: HyperEdgeSegment,
        _ segments: [HyperEdgeSegment]
    ) {
        guard let routingGenerator else {
            assertionFailure("routingGenerator must be set before splitting segments")
            return
        }

        guard let splitCausingSegment = segment.getSplitBy(),
              let splitPartner = segment.getSplitPartner() else { return }

        HyperEdgeSegmentDependency.createAndAddCritical(
            segment,
            splitCausingSegment
        )
        HyperEdgeSegmentDependency.createAndAddCritical(
            splitCausingSegment,
            splitPartner
        )

        for otherSegment in segments {
            if otherSegment !== splitCausingSegment && otherSegment !== segment && otherSegment !== splitPartner {
                routingGenerator.createDependencyIfNecessary(otherSegment, segment)
                routingGenerator.createDependencyIfNecessary(otherSegment, splitPartner)
            }
        }
    }

    package func computePositionToSplitAndUpdateFreeAreas(
        _ segment: HyperEdgeSegment,
        _ freeAreas: inout [FreeArea],
        _ criticalConflictThreshold: Double
    ) -> Double {
        var firstPossibleAreaIndex = -1
        var lastPossibleAreaIndex = -1

        for i in 0..<freeAreas.count {
            let currArea = freeAreas[i]

            if currArea.startPosition > segment.getEndCoordinate() {
                break
            } else if currArea.endPosition >= segment.getStartCoordinate() {
                if firstPossibleAreaIndex < 0 {
                    firstPossibleAreaIndex = i
                }
                lastPossibleAreaIndex = i
            }
        }

        var splitPosition = Self.center(segment)

        if firstPossibleAreaIndex >= 0 {
            let bestAreaIndex = chooseBestAreaIndex(segment, freeAreas, firstPossibleAreaIndex, lastPossibleAreaIndex)
            splitPosition = Self.center(freeAreas[bestAreaIndex])
            useArea(&freeAreas, bestAreaIndex, criticalConflictThreshold)
        }

        return splitPosition
    }

    package func chooseBestAreaIndex(
        _ segment: HyperEdgeSegment,
        _ freeAreas: [FreeArea],
        _ fromIndex: Int,
        _ toIndex: Int
    ) -> Int {
        var bestAreaIndex = fromIndex

        if fromIndex < toIndex {
            let splitSegments = segment.simulateSplit()
            let splitSegment = splitSegments.0
            let splitPartner = splitSegments.1

            var bestArea = freeAreas[bestAreaIndex]
            var bestRating = rateArea(segment, splitSegment, splitPartner, bestArea)

            if fromIndex + 1 <= toIndex {
                for i in (fromIndex + 1)...toIndex {
                    let currArea = freeAreas[i]
                    let currRating = rateArea(segment, splitSegment, splitPartner, currArea)

                    if isBetter(currArea, currRating, bestArea, bestRating) {
                        bestArea = currArea
                        bestRating = currRating
                        bestAreaIndex = i
                    }
                }
            }
        }

        return bestAreaIndex
    }

    package func rateArea(
        _ segment: HyperEdgeSegment,
        _ splitSegment: HyperEdgeSegment,
        _ splitPartner: HyperEdgeSegment,
        _ area: FreeArea
    ) -> AreaRating {
        let areaCentre = Self.center(area)

        splitSegment.setOutgoingConnectionCoordinates([areaCentre])
        splitPartner.setIncomingConnectionCoordinates([areaCentre])

        let rating = AreaRating(0, 0)

        for dependency in segment.getIncomingSegmentDependencies() {
            guard let otherSegment = dependency.getSource() else { continue }
            updateConsideringBothOrderings(rating, splitSegment, otherSegment)
            updateConsideringBothOrderings(rating, splitPartner, otherSegment)
        }

        for dependency in segment.getOutgoingSegmentDependencies() {
            guard let otherSegment = dependency.getTarget() else { continue }
            updateConsideringBothOrderings(rating, splitSegment, otherSegment)
            updateConsideringBothOrderings(rating, splitPartner, otherSegment)
        }

        rating.dependencies += 2
        if let splitBy = segment.getSplitBy() {
            rating.crossings += countCrossingsForSingleOrdering(splitSegment, splitBy)
            rating.crossings += countCrossingsForSingleOrdering(splitBy, splitPartner)
        }

        return rating
    }

    package func updateConsideringBothOrderings(
        _ rating: AreaRating,
        _ s1: HyperEdgeSegment,
        _ s2: HyperEdgeSegment
    ) {
        let crossingsS1LeftOfS2 = countCrossingsForSingleOrdering(s1, s2)
        let crossingsS2LeftOfS1 = countCrossingsForSingleOrdering(s2, s1)

        if crossingsS1LeftOfS2 == crossingsS2LeftOfS1 {
            if crossingsS1LeftOfS2 > 0 {
                rating.dependencies += 2
                rating.crossings += crossingsS1LeftOfS2
            }
        } else {
            rating.dependencies += 1
            rating.crossings += min(crossingsS1LeftOfS2, crossingsS2LeftOfS1)
        }
    }

    package func countCrossingsForSingleOrdering(
        _ left: HyperEdgeSegment,
        _ right: HyperEdgeSegment
    ) -> Int {
        OrthogonalRoutingGenerator.countCrossings(
            left.getOutgoingConnectionCoordinates(),
            right.getStartCoordinate(),
            right.getEndCoordinate()
        ) + OrthogonalRoutingGenerator.countCrossings(
            right.getIncomingConnectionCoordinates(),
            left.getStartCoordinate(),
            left.getEndCoordinate()
        )
    }

    package func isBetter(
        _ currArea: FreeArea,
        _ currRating: AreaRating,
        _ bestArea: FreeArea,
        _ bestRating: AreaRating
    ) -> Bool {
        if currRating.crossings < bestRating.crossings {
            return true
        } else if currRating.crossings == bestRating.crossings {
            if currRating.dependencies < bestRating.dependencies {
                return true
            } else if currRating.dependencies == bestRating.dependencies {
                if currArea.size > bestArea.size {
                    return true
                }
            }
        }

        return false
    }

    package func useArea(
        _ freeAreas: inout [FreeArea],
        _ usedAreaIndex: Int,
        _ criticalConflictThreshold: Double
    ) {
        let oldArea = freeAreas[usedAreaIndex]
        freeAreas.remove(at: usedAreaIndex)

        if oldArea.size / 2.0 >= criticalConflictThreshold {
            var insertIndex = usedAreaIndex
            let oldAreaCentre = Self.center(oldArea)

            let newEnd1 = oldAreaCentre - criticalConflictThreshold
            if oldArea.startPosition <= newEnd1 {
                let newArea1 = FreeArea(oldArea.startPosition, newEnd1)
                freeAreas.insert(newArea1, at: insertIndex)
                insertIndex += 1
            }

            let newStart2 = oldAreaCentre + criticalConflictThreshold
            if newStart2 <= oldArea.endPosition {
                let newArea2 = FreeArea(newStart2, oldArea.endPosition)
                freeAreas.insert(newArea2, at: insertIndex)
            }
        }
    }

    package static func center(_ segment: HyperEdgeSegment) -> Double {
        center(segment.getStartCoordinate(), segment.getEndCoordinate())
    }

    package static func center(_ area: FreeArea) -> Double {
        center(area.startPosition, area.endPosition)
    }

    package static func center(_ p1: Double, _ p2: Double) -> Double {
        (p1 + p2) / 2.0
    }

    package struct FreeArea {
        let startPosition: Double
        let endPosition: Double
        let size: Double

        init(_ startPosition: Double, _ endPosition: Double) {
            assert(endPosition >= startPosition)
            self.startPosition = startPosition
            self.endPosition = endPosition
            self.size = endPosition - startPosition
        }
    }

    package final class AreaRating {
        var dependencies: Int
        var crossings: Int

        init(_ dependencies: Int, _ crossings: Int) {
            self.dependencies = dependencies
            self.crossings = crossings
        }
    }
}
