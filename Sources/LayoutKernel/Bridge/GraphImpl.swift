// Concrete implementations of the ELK graph model protocols.
// These replace the excluded graph/impl classes with simple,
// array-backed implementations suitable for JSON import/export.

import Foundation

// MARK: - Base Property Holder

package class PropertyHolderBase: EObject, IPropertyHolder {
    package var propertyMap: [String: Any]?

    package init() {}

    @discardableResult
    package func setProperty(_ property: IProperty, _ value: Any?) -> Self {
        if let value = value {
            var map = propertyMap ?? [:]
            map[property.id] = value
            propertyMap = map
        } else {
            propertyMap?.removeValue(forKey: property.id)
        }
        return self
    }

    package func getProperty(_ property: IProperty) -> Any? {
        if let value = propertyMap?[property.id] {
            return value
        }
        return property.defaultValue
    }

    package func hasProperty(_ property: IProperty) -> Bool {
        return propertyMap?[property.id] != nil
    }

    @discardableResult
    package func copyProperties(_ holder: IPropertyHolder) -> Self {
        let other = holder.getAllProperties()
        if !other.isEmpty {
            var map = propertyMap ?? [:]
            map.merge(other) { _, new in new }
            propertyMap = map
        }
        return self
    }

    package func getAllProperties() -> [String: Any] {
        return propertyMap ?? [:]
    }

    // String-key overloads
    @discardableResult
    package func setProperty(_ key: String, _ value: Any?) -> Self {
        if let value = value {
            var map = propertyMap ?? [:]
            map[key] = value
            propertyMap = map
        } else {
            propertyMap?.removeValue(forKey: key)
        }
        return self
    }

    package func getProperty(_ key: String) -> Any? {
        return propertyMap?[key]
    }

    package func hasProperty(_ key: String) -> Bool {
        return propertyMap?[key] != nil
    }
}

// MARK: - Graph Element

package class GraphElementBase: PropertyHolderBase, EMapPropertyHolder, GraphElement {
    package var properties: [String: Any] { return propertyMap ?? [:] }
    package var labels: [GraphLabel] = []
    package var identifier: String?
}

// MARK: - Shape

package class GraphShapeBase: GraphElementBase, GraphShape {
    package var x: Double = 0
    package var y: Double = 0
    package var width: Double = 0
    package var height: Double = 0

    package func setDimensions(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    package func setLocation(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

// MARK: - Connectable Shape

package class GraphConnectableShapeBase: GraphShapeBase, GraphConnectableShape {
    package var outgoingEdges: [GraphEdge] = []
    package var incomingEdges: [GraphEdge] = []
}

// MARK: - Node

package final class GraphNodeImpl: GraphConnectableShapeBase, GraphNode {
    package var ports: [GraphPort] = []
    package var children: [GraphNode] = []
    package weak var _parent: AnyObject?
    package var parent: GraphNode? {
        get { return _parent as? GraphNode }
        set { _parent = newValue as AnyObject? }
    }
    package var containedEdges: [GraphEdge] = []

    package func isHierarchical() -> Bool {
        return !children.isEmpty
    }
}

// MARK: - Port

package final class GraphPortImpl: GraphConnectableShapeBase, GraphPort {
    package weak var _parent: AnyObject?
    package var parent: GraphNode? {
        get { return _parent as? GraphNode }
        set { _parent = newValue as AnyObject? }
    }
}

// MARK: - Label

package final class GraphLabelImpl: GraphShapeBase, GraphLabel {
    package weak var _parent: AnyObject?
    package var parent: GraphElement? {
        get { return _parent as? GraphElement }
        set { _parent = newValue as AnyObject? }
    }
    package var text: String = ""
}

// MARK: - Edge

package final class GraphEdgeImpl: GraphElementBase, GraphEdge {
    package weak var _containingNode: AnyObject?
    package var containingNode: GraphNode? {
        get { return _containingNode as? GraphNode }
        set { _containingNode = newValue as AnyObject? }
    }
    package var sources: [GraphConnectableShape] = []
    package var targets: [GraphConnectableShape] = []
    package var sections: [GraphEdgeSection] = []

    package func isHyperedge() -> Bool {
        return sources.count > 1 || targets.count > 1
    }

    package func isHierarchical() -> Bool {
        guard let containingNode = containingNode else { return false }
        for source in sources {
            let sourceNode = (source as? GraphNode) ?? (source as? GraphPort)?.parent
            if sourceNode === containingNode { return true }
            if sourceNode?.parent !== containingNode { return true }
        }
        for target in targets {
            let targetNode = (target as? GraphNode) ?? (target as? GraphPort)?.parent
            if targetNode === containingNode { return true }
            if targetNode?.parent !== containingNode { return true }
        }
        return false
    }

    package func isSelfloop() -> Bool {
        if sources.isEmpty || targets.isEmpty { return false }
        let sourceNodes = Set(sources.map { ObjectIdentifier(($0 as? GraphNode) ?? (($0 as? GraphPort)?.parent ?? $0) as AnyObject) })
        let targetNodes = Set(targets.map { ObjectIdentifier(($0 as? GraphNode) ?? (($0 as? GraphPort)?.parent ?? $0) as AnyObject) })
        return sourceNodes == targetNodes
    }

    package func isConnected() -> Bool {
        return !sources.isEmpty && !targets.isEmpty
    }
}

// MARK: - Edge Section

package final class GraphEdgeSectionImpl: PropertyHolderBase, EMapPropertyHolder, GraphEdgeSection {
    package var properties: [String: Any] { return propertyMap ?? [:] }
    package var startX: Double = 0
    package var startY: Double = 0
    package var endX: Double = 0
    package var endY: Double = 0
    package var bendPoints: [GraphBendPoint] = []
    package weak var _parent: AnyObject?
    package var parent: GraphEdge? {
        get { return _parent as? GraphEdge }
        set { _parent = newValue as AnyObject? }
    }
    package var outgoingShape: GraphConnectableShape?
    package var incomingShape: GraphConnectableShape?
    package var outgoingSections: [GraphEdgeSection] = []
    package var incomingSections: [GraphEdgeSection] = []
    package var identifier: String?

    package func setStartLocation(x: Double, y: Double) {
        self.startX = x
        self.startY = y
    }

    package func setEndLocation(x: Double, y: Double) {
        self.endX = x
        self.endY = y
    }
}

// MARK: - Bend Point

package final class GraphBendPointImpl: EObject {
    package var x: Double = 0
    package var y: Double = 0

    package init() {}
    package init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

extension GraphBendPointImpl: GraphBendPoint {
    package func set(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}
