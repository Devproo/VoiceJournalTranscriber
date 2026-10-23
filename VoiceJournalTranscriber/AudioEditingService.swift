//
//  AudioEditingService.swift
//  VoiceJournalTranscriber
//
//  Created by ipeerless on 23/10/2026.
//

import AVFoundation
import Foundation

enum AudioEditingError: LocalizedError {
    case invalidRange
    case exportFailed
    case exportCancelled

    var errorDescription: String? {
        switch self {
        case .invalidRange:
            return "Choose a valid section of the recording."
        case .exportFailed:
            return "The trimmed recording could not be exported."
        case .exportCancelled:
            return "Audio export was cancelled."
        }
    }
}

enum AudioEditingService {
    static func trim(
        sourceURL: URL,
        startTime: TimeInterval,
        endTime: TimeInterval,
        outputURL: URL
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let assetDuration = try await asset.load(.duration)
        let duration = CMTimeGetSeconds(assetDuration)

        guard duration.isFinite,
              startTime >= 0,
              endTime > startTime,
              endTime <= duration else {
            throw AudioEditingError.invalidRange
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioEditingError.exportFailed
        }

        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            end: CMTime(seconds: endTime, preferredTimescale: 600)
        )
        exportSession.shouldOptimizeForNetworkUse = false

        try await exportSession.export(to: outputURL, as: .m4a)
    }
}

