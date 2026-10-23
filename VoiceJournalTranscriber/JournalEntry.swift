//
//  Item.swift
//  VoiceJournalTranscriber
//
//  Created by ipeerless on 23/10/2026.
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
