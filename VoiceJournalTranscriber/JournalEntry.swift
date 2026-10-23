//
//  Item.swift
//  VoiceJournalTranscriber
//
//  Created by ipeerless on 23/10/2026.
//

import Foundation
import SwiftData

@Model
final class JournalEntry {
    var title: String
    var transcript: String
    var audioFileName: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        title: String = "New Voice Journal",
        transcript: String = "",
        audioFileName: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.title = title
        self.transcript = transcript
        self.audioFileName = audioFileName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
