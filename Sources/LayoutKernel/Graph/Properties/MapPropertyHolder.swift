import Foundation

/**
 * An implementation of `IPropertyHolder` based on a `Dictionary`.
 *
 * Perf note (measured 2026-07-10, ledger #31): one 80-node layout performs
 * ~26,800 property reads, 58% on three keys — but routing those keys to fixed
 * inline slots changed nothing (±1%, reverted). The cost of this API is not
 * the dictionary; it is the `Any` boxing and the `as?` unboxing at every call
 * site, which only a typed-accessor redesign (sweep-engine rewrite) removes.
 */
package class MapPropertyHolder: IPropertyHolder {

    /** map of property identifiers to their values. */
    package var propertyMap: [String: Any]?

    package init() {}

    /// Variant with `value:` label for compatibility
    @discardableResult
    package func setProperty(_ property: IProperty, value: Any?) -> Self {
        return setProperty(property, value)
    }

    @discardableResult
    package func setProperty(_ property: IProperty, _ value: Any?) -> Self {
        if let value = value {
            propertyMap = propertyMap ?? [:]
            propertyMap?[property.id] = value
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
    package func copyProperties(_ other: IPropertyHolder) -> Self {
        let otherMap = other.getAllProperties()
        if !otherMap.isEmpty {
            propertyMap = propertyMap ?? [:]
            propertyMap?.merge(otherMap) { _, new in new }
        }
        return self
    }

    package func getAllProperties() -> [String: Any] {
        return propertyMap ?? [:]
    }

    /// Removes every property. Graph teardown goes through this rather than
    /// assigning the storage field directly.
    package func clearAllProperties() {
        propertyMap = nil
    }

    // MARK: - String-key overloads for compatibility

    @discardableResult
    package func setProperty(_ key: String, _ value: Any?) -> Self {
        if let value = value {
            propertyMap = propertyMap ?? [:]
            propertyMap?[key] = value
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
