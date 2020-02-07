//
//  DataWindow.swift
//  Prefetched
//
//  Created by Ahmed Khalaf on 6/18/19.
//  Copyright © 2019 Ahmed Khalaf. All rights reserved.
//

import Foundation

class DataWindow<Element: ElementType> {
    // MARK: - Cache
    private lazy var cache = WindowCache<Element.IdType, Element>(pagesToRetain: 3)
    
    // MARK: - Data Fetcher
    typealias DataFetcher = ([Element.IdType]) throws -> [Element]
    private let dataFetcher: DataFetcher
    
    // MARK: - Init
    init(ids: [Element.IdType], windowSize: Int = 20, dataFetcher: @escaping DataFetcher, errorHandler: @escaping ErrorHandler) {
        self.ids = ids
        self.windowSize = windowSize
        self.dataFetcher = dataFetcher
        self.errorHandler = errorHandler
    }
    
    // MARK: - Error
    typealias ErrorHandler = (Error) -> Void
    let errorHandler: ErrorHandler
    
    // MARK: - Accessors
    subscript(index: Int) -> Element? {
        get {
            let element = cache[ids[index]]
            if element == nil {
                prefetch(index: index)
            }
            return element
        }
        
        set {
            cache[ids[index], page: page(forIndex: index)] = newValue
        }
    }
    
    subscript(index: Int, block block: Bool) -> Element? {
        let element = cache[ids[index]]
        if element == nil {
            prefetch(index: index)
        }
        
        if block && page(forIndex: index) == page {
            queue.sync {}
        }
        return element
    }
        
    // MARK: - Paging
    private var page = 0
    let ids: [Element.IdType]
    private let windowSize: Int
    private var isPrefetching = Atomic(false)
    private lazy var queue = DispatchQueue(label: "DataWindow.\(ObjectIdentifier(self))")
    private func page(forIndex index: Int) -> Int {
        return index / windowSize
    }
    func prefetch(index: Int) {
        guard
            (0..<ids.count).contains(index),
            !isPrefetching.value,
            cache[ids[index]] == nil
            else { return }
        isPrefetching.value = true
        page = page(forIndex: index)
        
        queue.async { [weak self, page] in
            guard let self = self else { return }
            let startIndex = page * self.windowSize
            let indexRange = startIndex..<min(self.ids.count, startIndex + self.windowSize)
            let ids = Array(self.ids[indexRange])
            
            do {
                let elements = try self.dataFetcher(ids)
                
                for (index, element) in elements.enumerated() {
                    self[startIndex + index] = element
                }
            } catch {
                self.errorHandler(error)
            }
            
            self.isPrefetching.value = false
        }
    }
}

protocol ElementType {
    associatedtype IdType: Hashable
    var id: IdType { get }
}

fileprivate struct WindowCache<Key: Hashable, Value> {
    
    // MARK: - Init
    init(pagesToRetain: Int = 5) {
        self.pagesToRetain = pagesToRetain
    }
    
    // MARK: - Storage
    private var dict = Atomic([Key : Item]())
    private struct Item {
        let value: Value
        let page: Int
    }
    
    // MARK: - Purging
    private let pagesToRetain: Int
    private var _lastReferencePage = 0
    private func shouldPurge(newPage: Int, oldPage: Int) -> Bool {
        return abs(newPage - oldPage) > pagesToRetain
    }
    private var lastReferencePage: Int {
        set {
            guard shouldPurge(newPage: newValue, oldPage: lastReferencePage) else { return }
            purge(for: newValue)
            _lastReferencePage = newValue
        }
        
        get {
            return _lastReferencePage
        }
    }
    private mutating func purge(for page: Int) {
        dict.mutate { [shouldPurge] (dict) in
            for (key, value) in dict {
                if shouldPurge(page, value.page) {
                    dict.removeValue(forKey: key)
                }
            }
        }
    }
    
    // MARK: - Accessors
    subscript(key: Key) -> Value? {
        return dict.value[key]?.value
    }
    
    subscript(key: Key, page page: Int) -> Value? {
        get {
            return dict.value[key]?.value
        }
        set {
            if let newValue = newValue {
                dict.value[key] = Item(value: newValue, page: page)
                lastReferencePage = page
            } else {
                dict.value.removeValue(forKey: key)
            }            
        }
    }
}

struct Atomic<T> {
    private var _value: T
    private let queue = DispatchQueue(label: "atomic")
    
    init(_ value: T) {
        _value = value
    }
    
    var value: T {
        get {
            return queue.sync { return _value }
        }
        
        set {
            queue.sync { _value = newValue }
        }
    }
    
    mutating func mutate(_ mutationBlock: (inout T) -> Void) {
        queue.sync {
            mutationBlock(&self._value)
        }
    }
}
