// Copyright (c) 2008, 2020 Kiel University and others.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0.
//
// SPDX-License-Identifier: EPL-2.0

import Foundation
import Synchronization

// MARK: - Supporting Types

/// Simple triple for storing dependency/support data
package final class DependencyTriple {
    package var firstId: String = ""
    package var secondId: String = ""
    package var value: Any?
    package init() {}
}

// MARK: - Main Service

package final class LayoutMetaDataService {
    private static let _instance = Mutex<LayoutMetaDataService?>(nil)

    /// Thread-safe access to the singleton. Auto-initializes on first access.
    package static var instance: LayoutMetaDataService {
        _instance.withLock { inst in
            if let inst { return inst }
            let created = LayoutMetaDataService()
            inst = created
            return created
        }
    }

    // All six maps are mutated on read-paths (suffix caches) and on registration.
    // Accessing them without synchronization from multiple render threads caused
    // EXC_BAD_ACCESS crashes in Dictionary's subscript. All of them live behind
    // one mutex.
    //
    // `Mutex` is non-reentrant. Methods that take the lock must not call other
    // methods that also take it; composing methods call only locked entry
    // points without taking the lock themselves.
    private struct Maps {
        var layoutAlgorithmMap = [String: LayoutAlgorithmData]()
        var layoutOptionMap = [String: LayoutOptionData]()
        var legacyLayoutOptionMap = [String: LayoutOptionData]()
        var layoutCategoryMap = [String: LayoutCategoryData]()
        var algorithmSuffixMap = [String: LayoutAlgorithmData]()
        var optionSuffixMap = [String: LayoutOptionData]()
    }

    private let _state = Mutex(Maps())

    private init() {
        LayoutMetaDataService.initElkReflect()
    }

    package static func getInstance(loader: Any? = nil) -> LayoutMetaDataService {
        return instance
    }

    package static func unload() {
        _instance.withLock { $0 = nil }
    }

    package static func initElkReflect() {
        // Register types with ElkReflect for property cloning support
        // Uses the (type, newFun:, cloneFun:) signature from ElkReflect
    }

    // MARK: - Registration

    package func registerAlgorithm(_ algorithmData: LayoutAlgorithmData) {
        _state.withLock { $0.layoutAlgorithmMap[algorithmData.id] = algorithmData }
    }

    package func registerOption(_ optionData: LayoutOptionData) {
        _state.withLock { maps in
            maps.layoutOptionMap[optionData.id] = optionData
            if let legacyIds = optionData.getLegacyIds() {
                for legacyId in legacyIds {
                    maps.legacyLayoutOptionMap[legacyId] = optionData
                }
            }
        }
    }

    package func registerCategory(_ categoryData: LayoutCategoryData) {
        _state.withLock { $0.layoutCategoryMap[categoryData.id] = categoryData }
    }

    package func registerLayoutMetaDataProviders(_ providers: ILayoutMetaDataProvider...) {
        for provider in providers {
            let registry = Registry()
            registry.service = self
            provider.apply(registry)
            registry.applyDependencies()
        }
        _state.withLock { $0.optionSuffixMap.removeAll() }
    }

    // MARK: - Queries

    package func getAlgorithmData(_ id: String) -> LayoutAlgorithmData? {
        _state.withLock { $0.layoutAlgorithmMap[id] }
    }

    package func getAlgorithmData() -> [LayoutAlgorithmData] {
        _state.withLock { Array($0.layoutAlgorithmMap.values) }
    }

    package func getAlgorithmData(by suffix: String) -> LayoutAlgorithmData? {
        guard !suffix.isEmpty else { return nil }
        return _state.withLock { maps in
            if let data = maps.algorithmSuffixMap[suffix] {
                return data
            }

            var data: LayoutAlgorithmData?
            for d in maps.layoutAlgorithmMap.values {
                let id = d.getId()
                if id.hasSuffix(suffix) && (suffix.count == id.count || id[id.index(id.endIndex, offsetBy: -suffix.count - 1)] == ".") {
                    if data != nil {
                        return nil
                    }
                    data = d
                }
            }

            if let found = data {
                maps.algorithmSuffixMap[suffix] = found
            }

            return data
        }
    }

    /// Alias for callers using the old name
    package func getAlgorithmDataBySuffix(_ suffix: String?) -> LayoutAlgorithmData? {
        guard let suffix = suffix else { return nil }
        return getAlgorithmData(by: suffix)
    }

    package func getAlgorithmData(bySuffixOrDefault algorithmId: String?, defaultId: String?) -> LayoutAlgorithmData? {
        // Composes locked calls — must not take the lock itself.
        if let algorithmId = algorithmId, !algorithmId.trimmingCharacters(in: .whitespaces).isEmpty {
            if let data = getAlgorithmData(by: algorithmId) {
                return data
            }
        }

        if let defaultId = defaultId, !defaultId.trimmingCharacters(in: .whitespaces).isEmpty {
            if let data = getAlgorithmData(by: defaultId) {
                return data
            }
        }

        return nil
    }

    /// Alias for callers using old name
    package func getAlgorithmDataBySuffixOrDefault(_ suffix: String?, _ defaultID: String?) -> LayoutAlgorithmData? {
        return getAlgorithmData(bySuffixOrDefault: suffix, defaultId: defaultID)
    }

    package func getOptionData(_ id: String) -> LayoutOptionData? {
        _state.withLock { maps in
            if let data = maps.layoutOptionMap[id] {
                return data
            }
            return maps.legacyLayoutOptionMap[id]
        }
    }

    package func getOptionData() -> [LayoutOptionData] {
        _state.withLock { Array($0.layoutOptionMap.values) }
    }

    package func getOptionData(by suffix: String) -> LayoutOptionData? {
        guard !suffix.isEmpty else { return nil }
        return _state.withLock { maps in
            if let data = maps.optionSuffixMap[suffix] {
                return data
            }

            var data: LayoutOptionData?

            for d in maps.layoutOptionMap.values {
                let id = d.id
                if id.hasSuffix(suffix) && (suffix.count == id.count || id[id.index(id.endIndex, offsetBy: -suffix.count - 1)] == ".") {
                    if data != nil {
                        return nil
                    }
                    data = d
                }
            }

            if data == nil {
                for d in maps.layoutOptionMap.values {
                    if let legacyIds = d.getLegacyIds() {
                        for id in legacyIds {
                            if id.hasSuffix(suffix) && (suffix.count == id.count || id[id.index(id.endIndex, offsetBy: -suffix.count - 1)] == ".") {
                                if data != nil {
                                    return nil
                                }
                                data = d
                            }
                        }
                    }
                }
            }

            if let found = data {
                maps.optionSuffixMap[suffix] = found
            }

            return data
        }
    }

    /// Alias for callers using bySuffix: label
    package func getOptionData(bySuffix suffix: String) -> LayoutOptionData? {
        return getOptionData(by: suffix)
    }

    package func getOptionData(for algorithm: LayoutAlgorithmData, targetType: LayoutOptionData.Target) -> [LayoutOptionData] {
        _state.withLock { maps in
            var result = [LayoutOptionData]()
            for option in maps.layoutOptionMap.values {
                if algorithm.knowsOption(option.id) || CoreOptions.ALGORITHM.id == option.id {
                    if option.getTargets().contains(targetType) {
                        result.append(option)
                    }
                }
            }
            return result
        }
    }

    package func getCategoryData(_ id: String) -> LayoutCategoryData? {
        _state.withLock { $0.layoutCategoryMap[id] }
    }

    package func getCategoryData() -> [LayoutCategoryData] {
        _state.withLock { Array($0.layoutCategoryMap.values) }
    }

    // MARK: - Registry

    package class Registry: ILayoutMetaDataProvider_Registry {

        package weak var service: LayoutMetaDataService?

        package var optionDependencies = [DependencyTriple]()
        package var optionSupport = [DependencyTriple]()

        package init() {}

        package func register(_ algorithmData: LayoutAlgorithmData) {
            service?.registerAlgorithm(algorithmData)
        }

        package func register(_ optionData: LayoutOptionData) {
            service?.registerOption(optionData)
        }

        package func register(_ categoryData: LayoutCategoryData) {
            service?.registerCategory(categoryData)
        }

        package func addDependency(_ sourceOption: String, _ targetOption: String, _ requiredValue: Any?) {
            let triple = DependencyTriple()
            triple.firstId = sourceOption
            triple.secondId = targetOption
            triple.value = requiredValue
            optionDependencies.append(triple)
        }

        package func addOptionSupport(_ algorithm: String, _ option: String, _ defaultValue: Any?) {
            let triple = DependencyTriple()
            triple.firstId = algorithm
            triple.secondId = option
            triple.value = defaultValue
            optionSupport.append(triple)
        }

        package func applyDependencies() {
            // Uses locked accessors on the service. The per-object mutations
            // below (dependencies.append / addKnownOption) happen only during
            // registration, which is serialized by LayoutEngine.registerAlgorithmsIfNeeded's
            // registration mutex — so no reader observes a partial state.
            for dep in optionDependencies {
                if let source = service?.getOptionData(dep.firstId),
                   let target = service?.getOptionData(dep.secondId) {
                    if let value = dep.value {
                        source.dependencies.append(Pair(first: target, second: value))
                    }
                }
            }

            for sup in optionSupport {
                if let algorithm = service?.getAlgorithmData(sup.firstId),
                   let option = service?.getOptionData(sup.secondId) {
                    algorithm.addKnownOption(option, defaultValue: sup.value)
                }
            }
        }
    }
}


// MARK: - Supporting Protocols and Classes

package protocol ILayoutMetaDataProviderRegistry {
    func register(_ algorithmData: LayoutAlgorithmData)
    func register(_ optionData: LayoutOptionData)
    func register(_ categoryData: LayoutCategoryData)
    func addDependency(_ sourceOption: String, _ targetOption: String, _ requiredValue: Any?)
    func addOptionSupport(_ algorithm: String, _ option: String, _ defaultValue: Any?)
}

extension LayoutMetaDataService.Registry: ILayoutMetaDataProviderRegistry {}
