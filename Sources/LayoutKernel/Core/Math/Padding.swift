import Foundation

/**
 * Stores the padding of an element.
 */
package class Padding: Spacing {

    package override init() {
        super.init()
    }

    package init(_ any: Double) {
        super.init(any, any, any, any)
    }

    package init(_ leftRight: Double, _ topBottom: Double) {
        super.init(topBottom, leftRight, topBottom, leftRight)
    }

    package override init(_ top: Double, _ right: Double, _ bottom: Double, _ left: Double) {
        super.init(top, right, bottom, left)
    }

    package init(_ other: Padding) {
        super.init(other.top, other.right, other.bottom, other.left)
    }
}
