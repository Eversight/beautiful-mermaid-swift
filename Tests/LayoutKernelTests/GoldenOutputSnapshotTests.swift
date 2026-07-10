// Golden-output snapshot tests for force-unwrap removal safety net.
//
// These tests exercise code paths that contain force unwraps.
// They capture structural properties of layout output so that
// replacing `!` with `guard let ... else { return }` cannot
// silently skip work without failing a test.

import XCTest
@testable import LayoutKernel

final class GoldenOutputSnapshotTests: XCTestCase {

    // MARK: - Helpers

    private func layoutGraph(_ graph: [String: Any]) throws -> [String: Any] {
        let elk = LayoutEngine()
        return try elk.layout(graph: graph)
    }

    private func children(_ result: [String: Any]) -> [[String: Any]] {
        result["children"] as? [[String: Any]] ?? []
    }

    private func edges(_ result: [String: Any]) -> [[String: Any]] {
        result["edges"] as? [[String: Any]] ?? []
    }

    private func sections(_ edge: [String: Any]) -> [[String: Any]] {
        edge["sections"] as? [[String: Any]] ?? []
    }

    private func assertPositiveSize(_ result: [String: Any], file: StaticString = #filePath, line: UInt = #line) {
        let w = result["width"] as? Double ?? 0
        let h = result["height"] as? Double ?? 0
        XCTAssertGreaterThan(w, 0, "Graph width should be > 0", file: file, line: line)
        XCTAssertGreaterThan(h, 0, "Graph height should be > 0", file: file, line: line)
    }

    private func assertAllNodesPositioned(_ nodes: [[String: Any]], file: StaticString = #filePath, line: UInt = #line) {
        for node in nodes {
            let id = node["id"] as? String ?? "?"
            let x = node["x"] as? Double ?? -1
            let y = node["y"] as? Double ?? -1
            XCTAssertGreaterThanOrEqual(x, 0, "Node \(id) x should be >= 0", file: file, line: line)
            XCTAssertGreaterThanOrEqual(y, 0, "Node \(id) y should be >= 0", file: file, line: line)
        }
    }

    private func assertAllEdgesRouted(_ edgeList: [[String: Any]], file: StaticString = #filePath, line: UInt = #line) {
        for edge in edgeList {
            let id = edge["id"] as? String ?? "?"
            let secs = sections(edge)
            XCTAssertFalse(secs.isEmpty, "Edge \(id) should have sections", file: file, line: line)
            for sec in secs {
                let start = sec["startPoint"] as? [String: Double]
                let end = sec["endPoint"] as? [String: Double]
                XCTAssertNotNil(start, "Edge \(id) section should have startPoint", file: file, line: line)
                XCTAssertNotNil(end, "Edge \(id) section should have endPoint", file: file, line: line)
            }
        }
    }

    // MARK: - Test 1: Edge Labels

    /// Exercises: LabelDummySwitcher, LabelSideSelector, LabelPlacer, LabelDummyInserter
    func testEdgeLabelsSnapshot() throws {
        let graph: [String: Any] = [
            "id": "root",
            "layoutOptions": [
                "elk.algorithm": "layered",
                "elk.edgeRouting": "ORTHOGONAL",
                "elk.edgeLabels.placement": "CENTER"
            ],
            "children": [
                ["id": "A", "width": 60, "height": 40],
                ["id": "B", "width": 60, "height": 40],
                ["id": "C", "width": 60, "height": 40],
                ["id": "D", "width": 60, "height": 40]
            ],
            "edges": [
                ["id": "e1", "sources": ["A"], "targets": ["B"],
                 "labels": [["text": "connects", "width": 60, "height": 14]]],
                ["id": "e2", "sources": ["A"], "targets": ["C"],
                 "labels": [["text": "also", "width": 30, "height": 14]]],
                ["id": "e3", "sources": ["B"], "targets": ["D"],
                 "labels": [["text": "leads to", "width": 50, "height": 14]]],
                ["id": "e4", "sources": ["C"], "targets": ["D"]]
            ]
        ]

        let result = try layoutGraph(graph)

        assertPositiveSize(result)
        let nodes = children(result)
        XCTAssertEqual(nodes.count, 4)
        assertAllNodesPositioned(nodes)

        let edgeList = edges(result)
        XCTAssertEqual(edgeList.count, 4)
        assertAllEdgesRouted(edgeList)

        // Labeled edges should have label positions
        for edge in edgeList {
            let id = edge["id"] as? String ?? ""
            if let labels = edge["labels"] as? [[String: Any]], !labels.isEmpty {
                for label in labels {
                    let lx = label["x"] as? Double
                    let ly = label["y"] as? Double
                    XCTAssertNotNil(lx, "Label on edge \(id) should have x position")
                    XCTAssertNotNil(ly, "Label on edge \(id) should have y position")
                }
            }
        }
    }

    // MARK: - Test 2: Self-Loops

    /// Exercises: PortRestorer, RoutingSlotAssigner, RoutingDirector, SelfLoopPreProcessor
    func testSelfLoopsSnapshot() throws {
        let graph: [String: Any] = [
            "id": "root",
            "layoutOptions": [
                "elk.algorithm": "layered",
                "elk.edgeRouting": "ORTHOGONAL"
            ],
            "children": [
                ["id": "n1", "width": 80, "height": 60,
                 "ports": [
                    ["id": "p1", "width": 5, "height": 5],
                    ["id": "p2", "width": 5, "height": 5],
                    ["id": "p3", "width": 5, "height": 5],
                    ["id": "p4", "width": 5, "height": 5]
                 ]] as [String: Any],
                ["id": "n2", "width": 60, "height": 40]
            ],
            "edges": [
                // Two self-loops on n1
                ["id": "e_self1", "sources": ["p1"], "targets": ["p2"]],
                ["id": "e_self2", "sources": ["p3"], "targets": ["p4"]],
                // Normal edge
                ["id": "e_normal", "sources": ["n1"], "targets": ["n2"]]
            ]
        ]

        let result = try layoutGraph(graph)

        assertPositiveSize(result)
        let nodes = children(result)
        XCTAssertEqual(nodes.count, 2)
        assertAllNodesPositioned(nodes)

        let edgeList = edges(result)
        XCTAssertEqual(edgeList.count, 3)
        assertAllEdgesRouted(edgeList)

        // Self-loop edges should have bend points (they route around the node)
        for edge in edgeList {
            let id = edge["id"] as? String ?? ""
            if id.hasPrefix("e_self") {
                let secs = sections(edge)
                for sec in secs {
                    let bends = sec["bendPoints"] as? [[String: Double]]
                    XCTAssertNotNil(bends, "Self-loop \(id) should have bend points")
                    if let bends = bends {
                        XCTAssertGreaterThan(bends.count, 0, "Self-loop \(id) should have at least 1 bend point")
                    }
                }
            }
        }
    }

    // MARK: - Test 3: Reversed Edges (cycle breaking)

    /// Exercises: LEdge.reverse(), SortByInputModelProcessor, GreedyCycleBreaker
    func testReversedEdgesSnapshot() throws {
        // Create a graph with backward edges that force cycle breaking
        let graph: [String: Any] = [
            "id": "root",
            "layoutOptions": [
                "elk.algorithm": "layered",
                "elk.edgeRouting": "ORTHOGONAL"
            ],
            "children": [
                ["id": "n1", "width": 40, "height": 30],
                ["id": "n2", "width": 40, "height": 30],
                ["id": "n3", "width": 40, "height": 30],
                ["id": "n4", "width": 40, "height": 30]
            ],
            "edges": [
                // Forward edges
                ["id": "e1", "sources": ["n1"], "targets": ["n2"]],
                ["id": "e2", "sources": ["n2"], "targets": ["n3"]],
                ["id": "e3", "sources": ["n3"], "targets": ["n4"]],
                // Backward edges (create cycles)
                ["id": "e4_back", "sources": ["n3"], "targets": ["n1"]],
                ["id": "e5_back", "sources": ["n4"], "targets": ["n2"]]
            ]
        ]

        let result = try layoutGraph(graph)

        assertPositiveSize(result)
        let nodes = children(result)
        XCTAssertEqual(nodes.count, 4)
        assertAllNodesPositioned(nodes)

        let edgeList = edges(result)
        XCTAssertEqual(edgeList.count, 5)
        assertAllEdgesRouted(edgeList)

        // Verify nodes are positioned in distinct layers (different x or y values)
        let positions = nodes.compactMap { $0["x"] as? Double }
        let uniquePositions = Set(positions.map { Int($0) })
        XCTAssertGreaterThan(uniquePositions.count, 1, "Nodes should span multiple layers")
    }

    // MARK: - Test 4: Multi-Layer with Long Edges

    /// Exercises: LongEdgeJoiner, NorthSouthPortPostprocessor, LabelDummySwitcher
    func testMultiLayerLongEdgesSnapshot() throws {
        let graph: [String: Any] = [
            "id": "root",
            "layoutOptions": [
                "elk.algorithm": "layered",
                "elk.edgeRouting": "ORTHOGONAL",
                "elk.direction": "RIGHT"
            ],
            "children": [
                ["id": "a", "width": 50, "height": 30],
                ["id": "b", "width": 50, "height": 30],
                ["id": "c", "width": 50, "height": 30],
                ["id": "d", "width": 50, "height": 30],
                ["id": "e", "width": 50, "height": 30],
                ["id": "f", "width": 50, "height": 30],
                ["id": "g", "width": 50, "height": 30]
            ],
            "edges": [
                // Chain edges
                ["id": "e1", "sources": ["a"], "targets": ["b"]],
                ["id": "e2", "sources": ["b"], "targets": ["c"]],
                ["id": "e3", "sources": ["c"], "targets": ["d"]],
                ["id": "e4", "sources": ["d"], "targets": ["e"]],
                // Long edges skipping multiple layers
                ["id": "e_long1", "sources": ["a"], "targets": ["d"]],
                ["id": "e_long2", "sources": ["a"], "targets": ["e"]],
                ["id": "e_long3", "sources": ["b"], "targets": ["e"]],
                // Side branches
                ["id": "e5", "sources": ["c"], "targets": ["f"]],
                ["id": "e6", "sources": ["c"], "targets": ["g"]]
            ]
        ]

        let result = try layoutGraph(graph)

        assertPositiveSize(result)
        let nodes = children(result)
        XCTAssertEqual(nodes.count, 7)
        assertAllNodesPositioned(nodes)

        let edgeList = edges(result)
        XCTAssertEqual(edgeList.count, 9)
        assertAllEdgesRouted(edgeList)

        // Long edges should have bend points
        for edge in edgeList {
            let id = edge["id"] as? String ?? ""
            if id.hasPrefix("e_long") {
                let secs = sections(edge)
                for sec in secs {
                    let bends = sec["bendPoints"] as? [[String: Double]]
                    XCTAssertNotNil(bends, "Long edge \(id) should have bend points")
                    if let bends = bends {
                        XCTAssertGreaterThan(bends.count, 0,
                            "Long edge \(id) should have at least 1 bend point")
                    }
                }
            }
        }

        // Verify directional ordering (RIGHT direction: x increases along path)
        let nodeXByID = Dictionary(uniqueKeysWithValues: nodes.compactMap { node -> (String, Double)? in
            guard let id = node["id"] as? String, let x = node["x"] as? Double else { return nil }
            return (id, x)
        })
        if let ax = nodeXByID["a"], let bx = nodeXByID["b"],
           let cx = nodeXByID["c"], let dx = nodeXByID["d"] {
            XCTAssertLessThan(ax, bx, "a should be left of b")
            XCTAssertLessThan(bx, cx, "b should be left of c")
            XCTAssertLessThanOrEqual(cx, dx, "c should be left of or equal to d")
        }
    }

    // MARK: - Test 5: Comment Nodes

    /// Exercises: CommentPreprocessor, CommentPostprocessor
    func testCommentNodesSnapshot() throws {
        let graph: [String: Any] = [
            "id": "root",
            "layoutOptions": [
                "elk.algorithm": "layered",
                "elk.edgeRouting": "ORTHOGONAL"
            ],
            "children": [
                ["id": "n1", "width": 60, "height": 40],
                ["id": "n2", "width": 60, "height": 40],
                ["id": "n3", "width": 60, "height": 40],
                ["id": "comment1", "width": 80, "height": 30,
                 "layoutOptions": ["elk.commentBox": "true"]] as [String: Any],
                ["id": "comment2", "width": 80, "height": 30,
                 "layoutOptions": ["elk.commentBox": "true"]] as [String: Any]
            ],
            "edges": [
                ["id": "e1", "sources": ["n1"], "targets": ["n2"]],
                ["id": "e2", "sources": ["n2"], "targets": ["n3"]],
                // Comment attachments
                ["id": "e_c1", "sources": ["comment1"], "targets": ["n1"]],
                ["id": "e_c2", "sources": ["comment2"], "targets": ["n2"]]
            ]
        ]

        let result = try layoutGraph(graph)

        assertPositiveSize(result)
        let nodes = children(result)
        XCTAssertEqual(nodes.count, 5)
        assertAllNodesPositioned(nodes)

        let edgeList = edges(result)
        // Comment attachment edges may not have sections (they are absorbed by
        // the comment preprocessor). Only assert normal edges are routed.
        let normalEdges = edgeList.filter {
            let id = $0["id"] as? String ?? ""
            return !id.hasPrefix("e_c")
        }
        assertAllEdgesRouted(normalEdges)
    }

    // MARK: - Test 6: Complex labeled multi-layer (combines multiple patterns)

    /// Exercises: Multiple force-unwrap paths simultaneously
    func testComplexGraphSnapshot() throws {
        let graph: [String: Any] = [
            "id": "root",
            "layoutOptions": [
                "elk.algorithm": "layered",
                "elk.direction": "DOWN",
                "elk.edgeRouting": "ORTHOGONAL",
                "elk.spacing.nodeNode": "40",
                "elk.layered.spacing.nodeNodeBetweenLayers": "60",
                "elk.edgeLabels.placement": "CENTER"
            ],
            "children": [
                ["id": "Start", "width": 80, "height": 40],
                ["id": "Process1", "width": 100, "height": 50],
                ["id": "Process2", "width": 100, "height": 50],
                ["id": "Decision", "width": 80, "height": 40],
                ["id": "End", "width": 80, "height": 40]
            ],
            "edges": [
                ["id": "e1", "sources": ["Start"], "targets": ["Process1"],
                 "labels": [["text": "init", "width": 25, "height": 14]]],
                ["id": "e2", "sources": ["Start"], "targets": ["Process2"]],
                ["id": "e3", "sources": ["Process1"], "targets": ["Decision"],
                 "labels": [["text": "check", "width": 35, "height": 14]]],
                ["id": "e4", "sources": ["Process2"], "targets": ["Decision"]],
                ["id": "e5", "sources": ["Decision"], "targets": ["End"],
                 "labels": [["text": "done", "width": 30, "height": 14]]],
                // Long backward edge
                ["id": "e6_back", "sources": ["Decision"], "targets": ["Start"],
                 "labels": [["text": "retry", "width": 32, "height": 14]]]
            ]
        ]

        let result = try layoutGraph(graph)

        assertPositiveSize(result)
        let nodes = children(result)
        XCTAssertEqual(nodes.count, 5)
        assertAllNodesPositioned(nodes)

        let edgeList = edges(result)
        XCTAssertEqual(edgeList.count, 6)
        assertAllEdgesRouted(edgeList)

        // All labeled edges should have positioned labels
        let labeledEdgeIDs: Set<String> = ["e1", "e3", "e5", "e6_back"]
        for edge in edgeList {
            let id = edge["id"] as? String ?? ""
            if labeledEdgeIDs.contains(id) {
                if let labels = edge["labels"] as? [[String: Any]] {
                    for label in labels {
                        XCTAssertNotNil(label["x"] as? Double,
                            "Label on edge \(id) should have x")
                        XCTAssertNotNil(label["y"] as? Double,
                            "Label on edge \(id) should have y")
                    }
                }
            }
        }

        // DOWN direction: y should generally increase along the chain
        let nodeYByID = Dictionary(uniqueKeysWithValues: nodes.compactMap { node -> (String, Double)? in
            guard let id = node["id"] as? String, let y = node["y"] as? Double else { return nil }
            return (id, y)
        })
        if let startY = nodeYByID["Start"], let endY = nodeYByID["End"] {
            XCTAssertLessThan(startY, endY, "Start should be above End in DOWN layout")
        }
    }
}
