//
//  ContentView.swift
//  VoiceJournalTranscriber
//
//  Created by ipeerless on 23/10/2026.
//

import SwiftUI
import SwiftData
import AVFoundation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \JournalEntry.createdAt, order: .reverse)
    private var entries: [JournalEntry]
    
    @StateObject private var recorder = AudioRecordingService()
    @State private var searchText = ""
    @State private var showingNewEntry = false
    @State private var showingRecordingName = false
    @State private var recordingTitle = "Voice Journal"
    @State private var pendingAudioURL: URL?
    
    private var filteredEntries: [JournalEntry] {
        guard !searchText.isEmpty else { return entries }
        
        return entries.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.transcript.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                recordingSection
                
                if filteredEntries.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "Your Voice Journal" : "No Entries Found",
                        systemImage: "waveform",
                        description: Text(
                            searchText.isEmpty
                            ? "Your saved journal entries will appear here."
                            : "Try another search term."
                        )
                    )
                    .listRowSeparator(.hidden)
                } else {
                    Section("Journal Entries") {
                        ForEach(filteredEntries) { entry in
                            NavigationLink {
                                JournalEntryDetailView(entry: entry)
                            } label: {
                                JournalEntryRow(entry: entry)
                            }
                        }
                        .onDelete(perform: deleteEntries)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Voice Journal")
            .searchable(text: $searchText, prompt: "Search your journal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New journal entry")
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                NewJournalEntryView()
            }
            .alert("Save Recording", isPresented: $showingRecordingName) {
                TextField("Recording title", text: $recordingTitle)
                
                Button("Cancel", role: .cancel) {
                    discardPendingRecording()
                }
                
                Button("Save") {
                    saveRecording()
                }
            } message: {
                Text("Give your recording a title.")
            }
            .alert(
                "Recording Error",
                isPresented: Binding(
                    get: { recorder.errorMessage != nil },
                    set: { if !$0 { recorder.clearError() } }
                )
            ) {
                Button("OK") {
                    recorder.clearError()
                }
            } message: {
                Text(recorder.errorMessage ?? "An unknown recording error occurred.")
            }
        }
    }
    
    private var recordingSection: some View {
        Section("Voice Recording") {
            HStack(spacing: 12) {
                Image(systemName: recorder.isRecording ? "waveform.circle.fill" : "mic.circle")
                    .font(.system(size: 38))
                    .foregroundStyle(recorder.isRecording ? .red : .primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(recorder.isRecording ? (recorder.isPaused ? "Recording Paused" : "Recording in Progress") : "Ready to Record")
                        .font(.headline)
                    
                    Text(formattedDuration(recorder.duration))
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            
            if !recorder.isRecording {
                Button {
                    Task {
                        await recorder.startRecording()
                    }
                } label: {
                    Label("Start Recording", systemImage: "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                HStack {
                    Button {
                        if recorder.isPaused {
                            recorder.resumeRecording()
                        } else {
                            recorder.pauseRecording()
                        }
                    } label: {
                        Label(
                            recorder.isPaused ? "Resume" : "Pause",
                            systemImage: recorder.isPaused ? "play.fill" : "pause.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(role: .destructive) {
                        pendingAudioURL = recorder.stopRecording()
                        guard pendingAudioURL != nil else { return }
                        
                        recordingTitle = "Voice Journal \(Date.now.formatted(date: .abbreviated, time: .shortened))"
                        showingRecordingName = true
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    private func saveRecording() {
        guard let audioURL = pendingAudioURL else { return }
        
        let title = recordingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = JournalEntry(
            title: title.isEmpty ? "Voice Journal" : title,
            audioFileName: audioURL.lastPathComponent
        )
        
        modelContext.insert(entry)
        
        do {
            try modelContext.save()
            pendingAudioURL = nil
        } catch {
            modelContext.delete(entry)
            recorder.setError("Could not save journal entry: \(error.localizedDescription)")
        }
    }
    
    private func discardPendingRecording() {
        guard let pendingAudioURL else { return }
        
        do {
            try FileManager.default.removeItem(at: pendingAudioURL)
            self.pendingAudioURL = nil
        } catch {
            recorder.setError("Could not delete recording: \(error.localizedDescription)")
        }
    }
    
    private func deleteEntries(at offsets: IndexSet) {
        let entriesToDelete = offsets.map { filteredEntries[$0] }
        
        for entry in entriesToDelete {
            if let fileName = entry.audioFileName {
                let audioURL = URL.documentsDirectory.appending(path: fileName)
                
                do {
                    try FileManager.default.removeItem(at: audioURL)
                } catch {
                    if (error as NSError).code != NSFileNoSuchFileError {
                        recorder.setError("Could not delete audio file: \(error.localizedDescription)")
                    }
                }
            }
            
            modelContext.delete(entry)
        }
        
        do {
            try modelContext.save()
        } catch {
            recorder.setError("Could not delete journal entries: \(error.localizedDescription)")
        }
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private struct JournalEntryRow: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: entry.audioFileName == nil ? "text.alignleft" : "waveform")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            if !entry.transcript.isEmpty {
                Text(entry.transcript)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text(entry.audioFileName == nil ? "No transcript yet" : "Recording saved")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 5)
    }
}

private struct NewJournalEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var transcript = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Journal Entry") {
                    TextField("Title", text: $title)
                    
                    TextField("Write your journal entry", text: $transcript, axis: .vertical)
                        .lineLimit(5...12)
                }
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveEntry)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveEntry() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let entry = JournalEntry(
            title: cleanTitle,
            transcript: cleanTranscript
        )
        
        modelContext.insert(entry)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(entry)
        }
    }
}




private struct JournalEntryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var isSpeakingTranscript = false
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    @Bindable var entry: JournalEntry
    
    @StateObject private var playback = AudioPlaybackService()
    @State private var isTranscribing = false
    @State private var transcriptionError: String?
    @State private var showingDeleteRecordingConfirmation = false
    @State private var showingTrimConfirmation = false
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 0
    @State private var isTrimming = false
    @State private var trimmedAudioURL: URL?
    
    private let transcriptionService = SpeechTranscriptionService()
    
    private var audioURL: URL? {
        guard let fileName = entry.audioFileName else { return nil }
        return URL.documentsDirectory.appending(path: fileName)
    }
    
    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $entry.title)
                
                Text("Created \(entry.createdAt.formatted(date: .long, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let audioURL {
                Section("Recording") {
                    if FileManager.default.fileExists(atPath: audioURL.path) {
                        Button {
                            if playback.isPlaying {
                                playback.pause()
                            } else {
                                playback.play(url: audioURL)
                            }
                        } label: {
                            Label(
                                playback.isPlaying ? "Pause Recording" : "Play Recording",
                                systemImage: playback.isPlaying ? "pause.fill" : "play.fill"
                            )
                        }
                        
                        VStack(spacing: 8) {
                            Slider(
                                value: Binding(
                                    get: { playback.currentTime },
                                    set: { playback.seek(to: $0) }
                                ),
                                in: 0...max(playback.duration, 0.01)
                            )
                            
                            HStack {
                                Text(formatTime(playback.currentTime))
                                Spacer()
                                Text(formatTime(playback.duration))
                            }
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        }
                        
                        Button(role: .destructive) {
                            showingDeleteRecordingConfirmation = true
                        } label: {
                            Label("Delete Recording", systemImage: "trash")
                        }
                        
                        if playback.duration > 0 {
                            trimSection(sourceURL: audioURL)
                        } else {
                            Button {
                                playback.play(url: audioURL)
                                playback.pause()
                                resetTrimRange()
                            } label: {
                                Label("Prepare Audio Trimming", systemImage: "scissors")
                            }
                        }
                    } else {
                        Text("The audio file could not be found.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            
            Section("Transcript") {
                TextField("Transcript", text: $entry.transcript, axis: .vertical)
                    .lineLimit(8...20)
                
                if !entry.transcript.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty {
                    HStack {
                        Button {
                            readTranscriptAloud()
                        } label: {
                            Label("Read Aloud", systemImage: "speaker.wave.2.fill")
                        }
                        
                        Button(role: .destructive) {
                            stopReadingTranscript()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .disabled(!isSpeakingTranscript)
                    }
                }
                
                if let fileName = entry.audioFileName {
                    Button {
                        Task {
                            await transcribe(fileName: fileName)
                        }
                    } label: {
                        if isTranscribing {
                            HStack {
                                ProgressView()
                                Text("Transcribing...")
                            }
                        } else {
                            Label(
                                entry.transcript.isEmpty
                                ? "Transcribe Recording"
                                : "Transcribe Again",
                                systemImage: "waveform"
                            )
                        }
                    }
                    .disabled(isTranscribing)
                }
            }
            
        }
        .navigationTitle("Journal Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    entry.updatedAt = .now
                    
                    do {
                        try modelContext.save()
                        dismiss()
                    } catch {
                        transcriptionError = "Could not save journal entry: \(error.localizedDescription)"
                    }
                }
            }
        }
        
        .onDisappear {
            playback.stop()
            stopReadingTranscript()
        }
        
        .confirmationDialog(
            "Delete this audio recording?",
            isPresented: $showingDeleteRecordingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Recording", role: .destructive) {
                deleteRecording()
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The audio file will be deleted. Your journal title and transcript will remain.")
        }
        .confirmationDialog(
            "Save trimmed recording?",
            isPresented: $showingTrimConfirmation,
            titleVisibility: .visible
        ) {
            Button("Save as New Recording") {
                saveTrimmedRecording()
            }
            
            Button("Replace Original Recording", role: .destructive) {
                replaceOriginalWithTrimmedRecording()
            }
            
            Button("Cancel", role: .cancel) {
                discardTrimmedRecording()
            }
        } message: {
            Text("The selected section has been exported. You can keep both recordings or replace the original.")
        }
        .alert(
            "Journal Error",
            isPresented: Binding(
                get: { transcriptionError != nil || playback.errorMessage != nil },
                set: {
                    if !$0 {
                        transcriptionError = nil
                        playback.clearError()
                    }
                }
            )
        ) {
            Button("OK") {
                transcriptionError = nil
                playback.clearError()
            }
        } message: {
            Text(transcriptionError ?? playback.errorMessage ?? "An unknown error occurred.")
        }
    }
    
    @ViewBuilder
    private func trimSection(sourceURL: URL) -> some View {
        Section("Trim Recording") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Start: \(formatTime(trimStart))")
                Slider(
                    value: $trimStart,
                    in: 0...max(trimEnd - 0.5, 0)
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("End: \(formatTime(trimEnd))")
                Slider(
                    value: $trimEnd,
                    in: min(trimStart + 0.5, playback.duration)...max(playback.duration, 0.5)
                )
            }
            
            Text("Selected length: \(formatTime(max(0, trimEnd - trimStart)))")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button {
                Task {
                    await createTrimmedRecording(sourceURL: sourceURL)
                }
            } label: {
                if isTrimming {
                    ProgressView("Trimming...")
                } else {
                    Label("Trim and Export", systemImage: "scissors")
                }
            }
            .disabled(isTrimming || trimEnd <= trimStart)
        }
        .onAppear {
            if trimEnd == 0 {
                resetTrimRange()
            }
        }
    }
    
    private func resetTrimRange() {
        let duration = playback.duration
        guard duration > 0 else { return }
        trimStart = 0
        trimEnd = duration
    }
    
    @MainActor
    private func createTrimmedRecording(sourceURL: URL) async {
        isTrimming = true
        defer { isTrimming = false }
        
        playback.stop()
        
        let outputURL = URL.documentsDirectory
            .appending(path: "trimmed-\(UUID().uuidString).m4a")
        
        do {
            try await AudioEditingService.trim(
                sourceURL: sourceURL,
                startTime: trimStart,
                endTime: trimEnd,
                outputURL: outputURL
            )
            
            trimmedAudioURL = outputURL
            showingTrimConfirmation = true
        } catch {
            transcriptionError = "Could not trim recording: \(error.localizedDescription)"
        }
    }
    
    private func saveTrimmedRecording() {
        guard let trimmedAudioURL else { return }
        
        let newEntry = JournalEntry(
            title: "\(entry.title) (Trimmed)",
            transcript: "",
            audioFileName: trimmedAudioURL.lastPathComponent
        )
        
        modelContext.insert(newEntry)
        
        do {
            try modelContext.save()
            self.trimmedAudioURL = nil
        } catch {
            modelContext.delete(newEntry)
            transcriptionError = "Could not save trimmed entry: \(error.localizedDescription)"
        }
    }
    
    private func replaceOriginalWithTrimmedRecording() {
        guard let trimmedAudioURL, let audioURL else { return }
        
        do {
            try FileManager.default.removeItem(at: audioURL)
            try FileManager.default.moveItem(at: trimmedAudioURL, to: audioURL)
            
            entry.updatedAt = .now
            try modelContext.save()
            self.trimmedAudioURL = nil
            resetTrimRange()
        } catch {
            transcriptionError = "Could not replace original recording: \(error.localizedDescription)"
        }
    }
    
    private func discardTrimmedRecording() {
        guard let trimmedAudioURL else { return }
        
        try? FileManager.default.removeItem(at: trimmedAudioURL)
        self.trimmedAudioURL = nil
    }
    
    
    private func deleteRecording() {
        playback.stop()
        
        if let audioURL {
            try? FileManager.default.removeItem(at: audioURL)
        }
        
        entry.audioFileName = nil
        
        if entry.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelContext.delete(entry)
        } else {
            entry.updatedAt = .now
        }
        
        try? modelContext.save()
    }
    
    
    @MainActor
    private func transcribe(fileName: String) async {
        isTranscribing = true
        defer { isTranscribing = false }
        
        playback.pause()
        
        let url = URL.documentsDirectory.appending(path: fileName)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            transcriptionError = "The audio recording could not be found."
            return
        }
        
        do {
            let result = try await transcriptionService.transcribe(audioURL: url)
            let cleanedTranscript = result.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !cleanedTranscript.isEmpty else {
                transcriptionError = "No speech was recognized. Try recording again with clearer audio."
                return
            }
            
            entry.transcript = cleanedTranscript
            entry.updatedAt = .now
            try modelContext.save()
        } catch {
            transcriptionError = error.localizedDescription
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let seconds = max(0, Int(time))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    
    
    private func readTranscriptAloud() {
        let text = entry.transcript.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        
        guard !text.isEmpty else { return }
        
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        speechSynthesizer.speak(utterance)
        isSpeakingTranscript = true
    }
    
    private func stopReadingTranscript() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeakingTranscript = false
    }
    
}


#Preview {
    ContentView()
        .modelContainer(for: JournalEntry .self, inMemory: true)
}
