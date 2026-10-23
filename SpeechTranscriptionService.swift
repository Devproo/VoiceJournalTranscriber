//
//  SpeechTranscriptionService.swift
//  VoiceJournalTranscriber
//
//  Created by ipeerless on 23/10/2026.
//


internal import Combine
import Foundation
import Speech

@MainActor
final class SpeechTranscriptionService: ObservableObject {
    func transcribe(audioURL: URL) async throws -> String {
        let authorization = await withCheckedContinuation {
            (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in

            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard authorization == .authorized else {
            throw TranscriptionError.notAuthorized
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale.current) else {
            throw TranscriptionError.languageUnavailable
        }

        guard recognizer.isAvailable else {
            throw TranscriptionError.serviceUnavailable
        }

        guard recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.onDeviceRecognitionUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let result, result.isFinal {
                    continuation.resume(
                        returning: result.bestTranscription.formattedString
                    )
                }
            }
        }
    }
}

enum TranscriptionError: LocalizedError {
    case notAuthorized
    case languageUnavailable
    case serviceUnavailable
    case onDeviceRecognitionUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Please allow speech recognition in Settings."
        case .languageUnavailable:
            return "Speech recognition is unavailable for your device language."
        case .serviceUnavailable:
            return "Speech recognition is temporarily unavailable. Please try again."
        case .onDeviceRecognitionUnavailable:
            return "On-device recognition is not supported for your current language. Try another supported language."
        }
    }
}

