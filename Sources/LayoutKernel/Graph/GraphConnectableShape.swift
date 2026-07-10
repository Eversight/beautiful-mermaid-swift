/**
 * Copyright (c) 2016 Kiel University and others.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * SPDX-License-Identifier: EPL-2.0
 */

import Foundation

/**
 * A graph element that can be the end point of an edge.
 *
 * The following features are supported:
 * - [[GraphConnectableShape.outgoingEdges]]: List of edges that leave this connectable shape.
 * - [[GraphConnectableShape.incomingEdges]]: List of edges that go into this connectable shape.
 */
package protocol GraphConnectableShape: GraphShape {
    
    /// List of edges that leave this connectable shape.
    /// Adding or removing an edge to/from this list automatically updates its list of sources.
    var outgoingEdges: [GraphEdge] { get set }
    
    /// List of edges that go into this connectable shape.
    /// Adding or removing an edge to/from this list automatically updates its list of targets.
    var incomingEdges: [GraphEdge] { get set }
}
