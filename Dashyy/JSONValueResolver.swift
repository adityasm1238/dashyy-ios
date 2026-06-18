//
//  JSONValueResolver.swift
//  Dashyy
//
//  Created by Antigravity on 18/06/26.
//

import Foundation

struct JSONValueResolver {
    /// Resolves a dot-notation keypath (e.g. "activeStreams.0.title") within a decoded JSON dictionary.
    static func resolve(path: String, in dictionary: [String: Any]) -> Any? {
        let cleanPath = path.hasPrefix("$.") ? String(path.dropFirst(2)) : path
        guard !cleanPath.isEmpty else { return dictionary }
        
        let parts = cleanPath.components(separatedBy: ".")
        var current: Any = dictionary
        
        for part in parts {
            // Check if it's a dictionary
            if let dict = current as? [String: Any] {
                guard let next = dict[part] else { return nil }
                current = next
            } 
            // Check if it's an array
            else if let array = current as? [Any] {
                guard let index = Int(part), index >= 0, index < array.count else { return nil }
                current = array[index]
            } 
            // Leaf node, cannot go deeper
            else {
                return nil
            }
        }
        return current
    }
    
    static func resolveString(path: String, in dictionary: [String: Any]) -> String? {
        guard let val = resolve(path: path, in: dictionary) else { return nil }
        if let str = val as? String { return str }
        if let num = val as? NSNumber { return num.stringValue }
        return String(describing: val)
    }
    
    static func resolveDouble(path: String, in dictionary: [String: Any]) -> Double? {
        guard let val = resolve(path: path, in: dictionary) else { return nil }
        if let doubleVal = val as? Double { return doubleVal }
        if let intVal = val as? Int { return Double(intVal) }
        if let floatVal = val as? Float { return Double(floatVal) }
        if let strVal = val as? String, let parsed = Double(strVal) { return parsed }
        return nil
    }
    
    static func resolveArray(path: String, in dictionary: [String: Any]) -> [[String: Any]]? {
        guard let val = resolve(path: path, in: dictionary) else { return nil }
        if let array = val as? [[String: Any]] { return array }
        if let array = val as? [Any] {
            return array.compactMap { $0 as? [String: Any] }
        }
        return nil
    }
}
