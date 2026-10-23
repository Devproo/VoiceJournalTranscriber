
# Voice Journal & Transcriber — Data Models

## 1. JournalEntry

Represents one saved voice-journal entry.

Fields:
- `id`: unique identifier
- `title`: editable entry title
- `transcript`: editable transcription text
- `audioFileName`: optional name of the locally stored audio file
- `createdAt`: date and time the entry was created
- `updatedAt`: date and time the entry was last edited

Responsibilities:
- Store the journal entry's title and transcript.
- Reference its associated audio file.
- Support editing and searching.
- Track creation and modification dates.

## 2. Recording Session

A recording session is temporary state while audio is being captured. It is not a persistent database model in the first version.

State:
- `idle`
- `recording`
- `paused`
- `stopped`

Runtime information:
- Recording start time
- Current duration
- Temporary audio file URL
- Recording error, if any

Responsibilities:
- Start, pause, resume, and stop recording.
- Track recording duration and state.
- Produce an audio file that can be saved with a journal entry.

## 3. Transcription

Transcription is initially an operation on a recorded audio file, not a separate database model.

Runtime state:
- `idle`
- `transcribing`
- `completed`
- `failed`

Responsibilities:
- Check whether on-device speech recognition is supported.
- Request authorization when required.
- Transcribe the recorded audio using Apple's Speech framework.
- Return text or a clear error.
- Allow the user to edit the returned text before or after saving.

## 4. Relationships

- A journal entry can reference one audio file.
- The audio file is stored in the app's local documents directory.
- The journal entry's metadata and transcript are stored locally using SwiftData.
- Recording and transcription states exist only while the relevant operation is running.

## 5. Deletion and File Safety

- Deleting a journal entry should also remove its associated audio file when appropriate.
- File deletion failures must not silently leave the app in an inconsistent state.
- Unsaved recordings should not become permanent journal entries automatically.

## 6. First-Version Decisions

- One entry has at most one recording.
- Transcripts can be empty when transcription is unavailable or skipped.
- Entries remain usable without transcription.
- No accounts, cloud synchronization, or third-party services.
- No separate User, Account, or Recording database model is needed for version one.
