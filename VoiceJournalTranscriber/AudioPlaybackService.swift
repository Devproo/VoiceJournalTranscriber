//
//  AudioPlaybackService.swift
//  VoiceJournalTranscriber
//
//  Created by ipeerless on 23/10/2026.
//

import AVFoundation
internal import Combine
import Foundation

@MainActor
final class AudioPlaybackService: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func play(url: URL) {
        do {
            if player?.url == url, let player {
                if player.currentTime >= player.duration {
                    player.currentTime = 0
                }

                player.play()
                isPlaying = true
                startTimer()
                return
            }

            stop()

            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.prepareToPlay()

            player = newPlayer
            duration = newPlayer.duration
            currentTime = 0

            guard newPlayer.play() else {
                errorMessage = "The recording could not be played."
                return
            }

            isPlaying = true
            startTimer()
        } catch {
            errorMessage = "Could not play recording: \(error.localizedDescription)"
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
        timer = nil
        currentTime = player?.currentTime ?? 0
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }

        player.currentTime = min(max(time, 0), player.duration)
        currentTime = player.currentTime

        if isPlaying {
            player.play()
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func startTimer() {
        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let player = self.player else { return }

                self.currentTime = player.currentTime

                if !player.isPlaying {
                    self.isPlaying = false
                    self.timer?.invalidate()
                    self.timer = nil
                }
            }
        }
    }
}

