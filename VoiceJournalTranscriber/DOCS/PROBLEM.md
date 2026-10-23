
# Voice Journal & Transcriber

## 1. Problem

People need a simple, private way to record their thoughts, keep voice journals, and turn speech into editable text without relying on a cloud service.

## 2. Goals

- Record audio and support pause, resume, and stop.
- Transcribe recordings using Apple's built-in Speech framework.
- Save recordings and journal entries locally on the device.
- Browse, search, and play saved entries.
- Edit entry titles and transcription text.
- Handle unavailable on-device speech recognition gracefully.

## 3. First-Version Scope

### Recording
- Start, pause, resume, and stop a recording.
- Show recording duration and current recording state.
- Save completed recordings locally.

### Transcription
- Request microphone and speech-recognition permission when needed.
- Check whether on-device recognition is supported before requesting it.
- Show transcription progress and any errors.
- Allow the user to edit the resulting text.

### Journal
- Create a journal entry from a recording.
- Edit its title and transcript.
- Browse and search saved entries.
- Play back the associated audio.

### Privacy and Storage
- Store audio files and journal data locally.
- Do not add accounts, cloud synchronization, or third-party transcription APIs.
- Explain permission requirements clearly.

## 4. Out of Scope

- User accounts and authentication.
- Cloud backups and synchronization.
- Paid transcription services.
- Sharing and collaboration.
- Document scanning features.

## 5. Initial Technical Direction

- Platform: iOS
- UI: SwiftUI
- Language: Swift
- Metadata and structured data: SwiftData, subject to confirming the model design.
- Audio: AVFoundation
- Speech recognition: Apple's Speech framework
- Audio files: local app storage

## 6. Success Criteria

- A user can record, pause, resume, and finish a voice recording.
- A completed recording remains available after restarting the app.
- The app can transcribe speech when supported and authorized.
- A user can edit, search, and replay saved journal entries.
- The app remains useful when transcription is unavailable.
- The first version works without an account or cloud connection.
