// Copyright (c) 2016 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0
//
// Swift port of org.eclipse.elk.alg.layered.p3order.counting.BinaryIndexedTreeTest

import XCTest
@testable import LayoutKernel

final class BinaryIndexedTreeTests: XCTestCase {

    func testSumBefore() {
        let tree = BinaryIndexedTree(5)
        tree.add(1)
        tree.add(2)
        tree.add(1)
        XCTAssertEqual(tree.rank(1), 0)
        XCTAssertEqual(tree.rank(2), 2)
    }

    func testSize() {
        let tree = BinaryIndexedTree(5)
        tree.add(2)
        tree.add(1)
        tree.add(1)
        XCTAssertEqual(tree.size(), 3)
    }

    func testRemoveAll() {
        let tree = BinaryIndexedTree(5)
        tree.add(0)
        tree.add(2)
        tree.add(1)
        tree.add(1)
        tree.removeAll(1)
        XCTAssertEqual(tree.size(), 2)
        XCTAssertEqual(tree.rank(2), 1)
        // Idempotent
        tree.removeAll(1)
        XCTAssertEqual(tree.size(), 2)
        XCTAssertEqual(tree.rank(2), 1)
    }
}
