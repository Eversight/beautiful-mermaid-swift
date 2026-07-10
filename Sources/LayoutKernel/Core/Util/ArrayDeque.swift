/// A minimal double-ended queue used by the layout pipeline's worklists.
///
/// Replaces Java's `ArrayDeque` where the original code used one. Backed by a
/// plain array: the pipeline's queues are small (one hierarchy level's nodes,
/// segment worklists), so O(n) `removeFirst` is irrelevant in practice and
/// value semantics keep call sites simple.
package struct ArrayDeque<Element> {
    private var storage: [Element]

    package init() {
        storage = []
    }

    package init(_ elements: [Element]) {
        storage = elements
    }

    package var isEmpty: Bool { storage.isEmpty }
    package var count: Int { storage.count }

    /// Appends to the tail (Java `addLast`/`add`/`offer`).
    package mutating func append(_ element: Element) {
        storage.append(element)
    }

    /// Appends a sequence to the tail (Java `addAll`).
    package mutating func append(contentsOf newElements: some Sequence<Element>) {
        storage.append(contentsOf: newElements)
    }

    /// Pushes onto the head (Java `push`/`addFirst`).
    package mutating func push(_ element: Element) {
        storage.insert(element, at: 0)
    }

    /// Removes and returns the head (Java `removeFirst`/`poll`).
    @discardableResult
    package mutating func removeFirst() -> Element {
        storage.removeFirst()
    }

    /// Removes and returns the tail (Java `removeLast`/`pollLast`).
    @discardableResult
    package mutating func removeLast() -> Element {
        storage.removeLast()
    }

    package mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        storage.removeAll(keepingCapacity: keepCapacity)
    }

    package func reversed() -> [Element] {
        storage.reversed()
    }
}

extension ArrayDeque: Sequence {
    package func makeIterator() -> IndexingIterator<[Element]> {
        storage.makeIterator()
    }
}
