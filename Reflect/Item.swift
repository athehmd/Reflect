//
//  Item.swift
//  Reflect
//
//  Created by Jovel Ramos on 1/9/25.
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
