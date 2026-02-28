import Foundation

/// Events emitted during voice input capture.
public enum VoiceInputEvent: Sendable, Equatable {
    case interimTranscript(String)
    case finalTranscript(String)
    case silenceDetected
    case audioLevel(Float)
    case error(VoiceInputError)
}

/// Errors during voice input.
public enum VoiceInputError: Error, Sendable, Equatable, LocalizedError {
    case microphoneUnavailable
    case permissionDenied
    case transcriptionFailed(String)
    case noSpeechDetected
    case modelNotReady

    public var errorDescription: String? {
        switch self {
        case .microphoneUnavailable:
            return "Microphone is not available"
        case .permissionDenied:
            return "Microphone permission was denied"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .noSpeechDetected:
            return "No speech was detected"
        case .modelNotReady:
            return "Speech recognition model is not ready"
        }
    }
}

/// Abstract speech output used by `VoicePracticeOrchestrator`.
public protocol VoicePracticeSpeechService: Sendable {
    func isAvailable() async -> Bool
    func speak(_ text: String, settings: VoicePracticeSettings) async throws
    func stop() async
}

/// Abstract speech input used by `VoicePracticeOrchestrator`.
public protocol VoicePracticeInputService: Sendable {
    func isMicrophoneAvailable() async -> Bool
    func requestPermission() async -> Bool
    func startListening(settings: VoicePracticeSettings) async -> AsyncThrowingStream<VoiceInputEvent, Error>
    func stopListening() async -> String?
    func cancelListening() async
}

/// Evaluates response quality and generates user-facing feedback.
public protocol VoiceResponseEvaluating: Sendable {
    func evaluate(
        userTranscript: String,
        question: String,
        correctAnswer: String
    ) async throws -> VoiceResponseEvaluation

    func generateFeedback(
        for evaluation: VoiceResponseEvaluation,
        question: String,
        correctAnswer: String
    ) async throws -> String
}

/// Session storage boundary for persistence/restore behavior.
public protocol VoicePracticeSessionStore: Sendable {
    func save(session: VoicePracticeSession, forKey key: String) async throws
    func loadSession(forKey key: String) async throws -> VoicePracticeSession?
    func clearSession(forKey key: String) async throws
}

/// Learning history boundary for app-level recording.
public protocol VoicePracticeHistoryRecording: Sendable {
    func recordInteraction(
        question: VoicePracticeQuestion,
        transcript: String,
        evaluation: VoiceResponseEvaluation
    ) async
}

/// Reward boundary for app-level XP and achievements.
public protocol VoicePracticeRewarding: Sendable {
    func awardXP(amount: Int, reason: String) async
}

/// Logging boundary for diagnostics.
public protocol VoicePracticeLogging: Sendable {
    func log(_ message: String) async
}
