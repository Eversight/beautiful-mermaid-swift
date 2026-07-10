import Foundation

package class AbstractSelfLoopRouter {

    package init() {}

    package func routeSelfLoops(_ slHolder: SelfLoopHolder) {
        assertionFailure("Subclasses must override routeSelfLoops")
    }
}
