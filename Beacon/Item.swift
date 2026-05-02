//
//  Item.swift
//  Beacon
//
//  Created by Jay Jones on 5/2/26.
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
