//
//  AudioRecordingService.swift
//  VoiceJournalTranscriber
//
//  Created by ipeerless on 23/10/2026.
//

import AVFoundation
import Foundation
internal import Combine

@MainActor
final class AudioRecordingService: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var audioURL: URL?
    @Published private(set) var errorMessage: String?
    
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var recordingStartedAt: Date?
    private var accumulatedDuration: TimeInterval = 0
    
    override init() {
        super.init()
    }
    
    func startRecording() async {
        guard !isRecording else { return }
        
        errorMessage = nil
        
        let permissionGranted = await requestMicrophonePermission()
        
        guard permissionGranted else {
            errorMessage = "Microphone access is required to record audio."
            return
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            
            let fileName = "\(UUID().uuidString).m4a"
            let url = URL.documentsDirectory.appending(path: fileName)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.delegate = self
            newRecorder.isMeteringEnabled = true
            
            guard newRecorder.record() else {
                throw RecordingError.couldNotStart
            }
            
            recorder = newRecorder
            audioURL = url
            duration = 0
            accumulatedDuration = 0
            recordingStartedAt = .now
            isRecording = true
            isPaused = false
            
            startTimer()
        } catch {
            errorMessage = "Could not start recording: \(error.localizedDescription)"
        }
    }
    
    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        
        recorder?.pause()
        accumulateElapsedTime()
        timer?.invalidate()
        timer = nil
        isPaused = true
    }
    
    func resumeRecording() {
        guard isRecording, isPaused else { return }
        
        guard recorder?.record() == true else {
            errorMessage = "Could not resume recording."
            return
        }
        
        recordingStartedAt = .now
        isPaused = false
        startTimer()
    }
    
    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        
        if !isPaused {
            accumulateElapsedTime()
        }
        
        timer?.invalidate()
        timer = nil
        
        recorder?.stop()
        recorder = nil
        
        isRecording = false
        isPaused = false
        recordingStartedAt = nil
        
        return audioURL
    }
    
    func discardRecording() {
        _ = stopRecording()
        
        if let audioURL {
            do {
                try FileManager.default.removeItem(at: audioURL)
            } catch {
                errorMessage = "Could not remove recording: \(error.localizedDescription)"
            }
        }
        
        audioURL = nil
        duration = 0
        accumulatedDuration = 0
    }
    
    
    private func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
    
    
    private func startTimer() {
        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isRecording, !self.isPaused else { return }

                self.duration = self.accumulatedDuration
                    + Date.now.timeIntervalSince(self.recordingStartedAt ?? .now)
            }
        }
    }

    private func accumulateElapsedTime() {
        if let recordingStartedAt {
            accumulatedDuration += Date.now.timeIntervalSince(recordingStartedAt)
        }
        
        duration = accumulatedDuration
        recordingStartedAt = nil
    }
    
    
    func clearError() {
        errorMessage = nil
    }

    func setError(_ message: String) {
        errorMessage = message
    }

}


extension AudioRecordingService: @preconcurrency AVAudioRecorderDelegate {
    func audioRecorderEncodeErrorDidOccur(
        _ recorder: AVAudioRecorder,
        error: Error?
    ) {
        if let error {
            errorMessage = "Recording error: \(error.localizedDescription)"
        }
    }
    
    func audioRecorderDidFinishRecording(
        _ recorder: AVAudioRecorder,
        successfully flag: Bool
    ) {
        if !flag {
            errorMessage = "The recording did not finish successfully."
        }
    }
}


private enum RecordingError: LocalizedError {
    case couldNotStart
    
    var errorDescription: String? {
        switch self {
        case .couldNotStart:
            return "The audio recorder could not start."
        }
    }
}

