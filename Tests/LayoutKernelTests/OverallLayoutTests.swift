// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of ELK overall layout tests.

import XCTest
@testable import LayoutKernel

final class OverallLayoutTests: XCTestCase {
    private var result: [String: Any]!

    override func setUp() {
        super.setUp()
        let elk = LayoutEngine()
        let graph: [String: Any] = [
            "id": "root",
            "layoutOptions": [
                "elk.algorithm": "layered",
                "elk.edgeRouting": "ORTHOGONAL"
            ],
            "children": [
                ["id": "n1", "width": 30, "height": 30],
                ["id": "n2", "width": 30, "height": 30]
            ],
            "edges": [
                ["id": "e1", "sources": ["n1"], "targets": ["n2"]]
            ]
        ]
        result = try! elk.layout(graph: graph)
    }

    func testNodeCoordinates() {
        let children = result["children"] as! [[String: Any]]
        // All coordinates should be non-negative (first node may be at origin)
        for child in children {
            XCTAssertGreaterThanOrEqual(child["x"] as! Double, 0,
                "Node \(child["id"] ?? "?") should have x >= 0")
            XCTAssertGreaterThanOrEqual(child["y"] as! Double, 0,
                "Node \(child["id"] ?? "?") should have y >= 0")
        }
        // At least one node should have a non-zero coordinate (not all at origin)
        let hasNonZero = children.contains {
            ($0["x"] as! Double) > 0 || ($0["y"] as! Double) > 0
        }
        XCTAssertTrue(hasNonZero, "At least one node should have non-zero coordinates")
    }

    func testEdgeCoordinates() {
        let edges = result["edges"] as! [[String: Any]]
        for edge in edges {
            let sections = edge["sections"] as! [[String: Any]]
            for section in sections {
                let start = section["startPoint"] as! [String: Double]
                let end = section["endPoint"] as! [String: Double]
                XCTAssertGreaterThan(start["x"]!, 0, "Edge start x should be > 0")
                XCTAssertGreaterThan(start["y"]!, 0, "Edge start y should be > 0")
                XCTAssertGreaterThan(end["x"]!, 0, "Edge end x should be > 0")
                XCTAssertGreaterThan(end["y"]!, 0, "Edge end y should be > 0")
            }
        }
    }

    func testGraphSize() {
        XCTAssertGreaterThan(result["width"] as! Double, 0, "Graph width should be > 0")
        XCTAssertGreaterThan(result["height"] as! Double, 0, "Graph height should be > 0")
    }

    func testEdgeOrthogonality() {
        let edges = result["edges"] as! [[String: Any]]
        for edge in edges {
            let sections = edge["sections"] as! [[String: Any]]
            for section in sections {
                let start = section["startPoint"] as! [String: Double]
                let end = section["endPoint"] as! [String: Double]
                var points: [(x: Double, y: Double)] = [(start["x"]!, start["y"]!)]
                if let bends = section["bendPoints"] as? [[String: Double]] {
                    for bend in bends {
                        points.append((bend["x"]!, bend["y"]!))
                    }
                }
                points.append((end["x"]!, end["y"]!))
                // Each segment must be horizontal or vertical
                for i in 0..<(points.count - 1) {
                    let dx = abs(points[i].x - points[i + 1].x)
                    let dy = abs(points[i].y - points[i + 1].y)
                    XCTAssert(dx < 0.05 || dy < 0.05,
                        "Edge segment not orthogonal: (\(points[i].x), \(points[i].y)) -> (\(points[i + 1].x), \(points[i + 1].y))")
                }
            }
        }
    }
}
