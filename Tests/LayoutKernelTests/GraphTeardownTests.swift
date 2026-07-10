import XCTest
@testable import LayoutKernel

/// The layered graph is cyclic by design (`LGraph ↔ Layer ↔ LNode`,
/// `LPort ↔ LEdge`, `LNode ↔ nested LGraph`, property-carried element
/// references). The Java original relies on GC; under ARC these cycles leaked
/// every laid-out graph until `LGraph.tearDown()` was introduced. This test
/// locks in that teardown actually frees every element kind.
final class GraphTeardownTests: XCTestCase {

    func testTearDownBreaksAllGraphCycles() {
        weak var weakGraph: LGraph?
        weak var weakLayer: Layer?
        weak var weakNodeA: LNode?
        weak var weakNodeB: LNode?
        weak var weakPort: LPort?
        weak var weakEdge: LEdge?
        weak var weakNested: LGraph?

        autoreleasepool {
            let graph = LGraph()
            let layer = graph.addLayer()

            let a = LNode(graph)
            let b = LNode(graph)
            a.layer = layer
            b.layer = layer
            layer.nodes = [a, b]

            let pa = LPort()
            pa.owner = a
            a.ports.append(pa)
            let pb = LPort()
            pb.owner = b
            b.ports.append(pb)

            let edge = LEdge()
            edge.source = pa
            edge.target = pb
            pa.outgoingEdges.append(edge)
            pb.incomingEdges.append(edge)

            // Property-carried references form cycles too (e.g. barycenter
            // associates); teardown must clear property maps.
            _ = a.setProperty("test.associates", [b])
            _ = graph.setProperty("test.backref", a)

            // Nested (compound) graph cycle.
            let nested = LGraph()
            nested.parentNode = b
            b.nestedGraph = nested

            weakGraph = graph
            weakLayer = layer
            weakNodeA = a
            weakNodeB = b
            weakPort = pa
            weakEdge = edge
            weakNested = nested

            graph.tearDown()
        }

        XCTAssertNil(weakGraph, "LGraph leaked after tearDown")
        XCTAssertNil(weakLayer, "Layer leaked after tearDown")
        XCTAssertNil(weakNodeA, "LNode leaked after tearDown")
        XCTAssertNil(weakNodeB, "LNode (property-referenced) leaked after tearDown")
        XCTAssertNil(weakPort, "LPort leaked after tearDown")
        XCTAssertNil(weakEdge, "LEdge leaked after tearDown")
        XCTAssertNil(weakNested, "nested LGraph leaked after tearDown")
    }

    /// Dummy nodes removed from the layers during post-processing are only
    /// reachable through edges; `tearDown` must follow edge endpoints or the
    /// strong `LPort.owner` backref keeps whole orphan clusters alive.
    func testTearDownFreesOrphanNodesReachableOnlyThroughEdges() {
        weak var weakOrphan: LNode?
        weak var weakOrphanPort: LPort?

        autoreleasepool {
            let graph = LGraph()
            let layer = graph.addLayer()

            let live = LNode(graph)
            live.layer = layer
            layer.nodes = [live]
            let livePort = LPort()
            livePort.owner = live
            live.ports.append(livePort)

            // Orphan: never added to any layer, referenced only via the edge.
            let orphan = LNode(graph)
            let orphanPort = LPort()
            orphanPort.owner = orphan
            orphan.ports.append(orphanPort)

            let edge = LEdge()
            edge.source = livePort
            edge.target = orphanPort
            livePort.outgoingEdges.append(edge)
            orphanPort.incomingEdges.append(edge)

            weakOrphan = orphan
            weakOrphanPort = orphanPort

            graph.tearDown()
        }

        XCTAssertNil(weakOrphan, "orphan LNode leaked after tearDown")
        XCTAssertNil(weakOrphanPort, "orphan LPort leaked after tearDown")
    }

    /// End-to-end guard: a full ELK layout run must not accumulate memory.
    /// Catches any future cycle anywhere in the pipeline (layered graph,
    /// bridge graph, network simplex, routing, node-size contexts, monitors).
    func testRepeatedLayoutDoesNotAccumulateMemory() throws {
        var children: [[String: Any]] = []
        var edges: [[String: Any]] = []
        for i in 0..<40 {
            children.append(["id": "n\(i)", "width": 120.0, "height": 40.0])
            if i + 1 < 40 { edges.append(["id": "e\(i)a", "sources": ["n\(i)"], "targets": ["n\(i + 1)"]]) }
            if i + 3 < 40 { edges.append(["id": "e\(i)b", "sources": ["n\(i)"], "targets": ["n\(i + 3)"]]) }
        }
        let graph: [String: Any] = [
            "id": "root",
            "layoutOptions": ["elk.algorithm": "layered"],
            "children": children,
            "edges": edges,
        ]

        let elk = try LayoutEngine()
        // Warm-up: singletons, caches, allocator high-water marks.
        for _ in 0..<3 {
            try autoreleasepool { _ = try elk.layout(graph: graph) }
        }

        guard let before = Self.physFootprint() else { throw XCTSkip("task_info unavailable") }
        for _ in 0..<25 {
            try autoreleasepool { _ = try elk.layout(graph: graph) }
        }
        guard let after = Self.physFootprint() else { throw XCTSkip("task_info unavailable") }

        let growth = after - before
        // The pre-fix leak grew ~1 MB per 40-node layout (~25 MB here).
        // Healthy growth is ~0 MB; 12 MB fails hard on a real leak while
        // leaving a wide margin against allocator noise.
        XCTAssertLessThan(
            growth, 12 * 1024 * 1024,
            "repeated layouts grew the physical footprint by \(growth / 1024) KB"
        )
    }

    private static func physFootprint() -> Int64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }
        return Int64(info.phys_footprint)
    }
}
