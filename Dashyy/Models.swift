//
//  Models.swift
//  Dashyy
//
//  Created by Antigravity on 18/06/26.
//

import Foundation

// MARK: - Dashboard Layout Models

struct DashboardTheme: Codable {
    let backgroundColors: [String]
    let accentColor: String
}

struct DashboardConfig: Codable, Identifiable {
    var id: String { title }
    let title: String
    let refreshInterval: Int?
    let theme: DashboardTheme?
    let sections: [DashboardSection]
    let cards: [String: CardConfig] // Maps card ID to full Card configuration
}

struct DashboardSection: Codable, Identifiable {
    let id: String
    let title: String
    let columns: Int
    let cardIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case columns
        case cardIds = "cards"
    }
}

enum CardSize: String, Codable {
    case small
    case medium
    case large
}

struct CardDataSource: Codable {
    let url: String?
    let token: String?
}

struct CardConfig: Codable, Identifiable {
    let id: String
    let title: String
    let size: CardSize
    let dataSource: CardDataSource?
    let widgets: [WidgetConfig]
}

// MARK: - Server-Driven UI Widget Model

struct ThresholdConfig: Codable {
    let value: Double
    let color: String // "red", "orange", "green"
}

struct WidgetConfig: Codable, Identifiable {
    var id: String {
        if let stable = _stableId {
            return stable
        }
        var properties = [
            type,
            valuePath ?? "",
            text ?? "",
            icon ?? "",
            color ?? "",
            String(size ?? 0.0),
            actionPath ?? "",
            direction ?? ""
        ]
        if let children = children {
            for child in children {
                properties.append(child.id)
            }
        }
        return properties.joined(separator: "|")
    }
    
    private let _stableId: String?
    
    enum CodingKeys: String, CodingKey {
        case _stableId = "id"
        case type
        case children
        case text
        case valuePath
        case icon
        case color
        case size
        case isBold
        case mappings
        case thresholds
        case chartType
        case xKey
        case yKeys
        case seriesLabels
        case colors
        case unit
        case arrayPath
        case itemLayout
        case actionPath
        case direction
        case lineLimit
    }
    
    let type: String
    let children: [WidgetConfig]?
    let text: String?
    let valuePath: String?
    let icon: String?
    let color: String?
    let size: Double?
    let isBold: Bool?
    let mappings: [String: String]?
    let thresholds: [ThresholdConfig]?
    let chartType: String?
    let xKey: String?
    let yKeys: [String]?
    let seriesLabels: [String]?
    let colors: [String]?
    let unit: String?
    let arrayPath: String?
    let itemLayout: [WidgetConfig]?
    let actionPath:  String?
    let direction: String?
    let lineLimit: Int?
}
