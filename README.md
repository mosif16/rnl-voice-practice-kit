# rnl-voice-practice-kit

Swift package: `VoicePracticeKit`

## Scope (first extraction slice)

Extracted reusable Voice Practice core from the app:

- Voice practice domain models
- State machine types and errors
- Service contracts (speech/input/evaluation/persistence/history/rewards)
- Orchestrator logic with dependency injection
- Keyword-based evaluation engine

## Intentionally not included

- SwiftUI screens and view models
- AVFoundation-backed speech/input concrete services
- App-specific analytics, XP manager, and history store adapters

## Migration notes

- Old singleton usage in app code must be replaced with dependency injection into `VoicePracticeOrchestrator`.
- App-specific models (`FlashCard`, `QuizQuestion`) can interoperate via source protocols:
  - `VoicePracticeFlashcardSource`
  - `VoicePracticeQuizQuestionSource`
- Session persistence is protocol-based; use `UserDefaultsVoicePracticeSessionStore` or custom store.

## Build and test

```bash
swift build -c release
swift test -c release
```

## Local release (no GitHub Actions)

```bash
scripts/release_local.sh
```
