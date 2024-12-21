//
//  Item.swift
//  WorkTime
//
//  Created by Jordan Payez on 23/11/2024.
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
