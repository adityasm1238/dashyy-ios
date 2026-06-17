//
//  Item.swift
//  Dashyy
//
//  Created by Aditya Madhyastha  on 17/06/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
