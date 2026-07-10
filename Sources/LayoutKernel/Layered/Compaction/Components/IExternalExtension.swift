/**
 * Container protocol for edges that represent external edges.
 */
package protocol IExternalExtension {
    /// The underlying edge representative.
    var representative: Any { get }

    /// The rectangle that represents the external extension.
    var representor: Rectangle { get }

    /// An optional placeholder along the original diagram's boundary.
    var placeholder: Rectangle? { get }

    /// The rectangle to which this extension connects.
    var parent: Rectangle { get }

    /// The direction into which this extension points.
    var direction: Direction { get }
}

// Default implementation for placeholder
extension IExternalExtension {
    package var placeholder: Rectangle? {
        return nil
    }
}
