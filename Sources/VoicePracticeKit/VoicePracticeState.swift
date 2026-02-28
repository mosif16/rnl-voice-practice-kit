import Foundation

/// State machine states for voice practice sessions.
public enum VoicePracticeState: Sendable, Equatable {
    case idle
    case speakingQuestion(index: Int)
    case listening(startTime: Date)
    case evaluating(transcript: String)
    case speakingFeedback(evaluation: VoiceResponseEvaluation)
    case awaitingNext
    case complete(summary: VoicePracticeSummary)
    case error(VoicePracticeError)

    public var isActive: Bool {
        switch self {
        case .idle, .complete, .error:
            return false
        default:
            return true
        }
    }

    public var isSpeaking: Bool {
        switch self {
        case .speakingQuestion, .speakingFeedback:
            return true
        default:
            return false
        }
    }

    public var isListening: Bool {
        if case .listening = self {
            return true
        }
        return false
    }

    public var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .speakingQuestion(let index):
            return "Question \(index + 1)"
        case .listening:
            return "Listening..."
        case .evaluating:
            return "Thinking..."
        case .speakingFeedback:
            return "Speaking..."
        case .awaitingNext:
            return "Your turn"
        case .complete:
            return "Practice Complete"
        case .error(let error):
            return error.localizedDescription
        }
    }

    /// Unique identifier for animation or state-diff tooling.
    public var stateIdentifier: String {
        switch self {
        case .idle:
            return "idle"
        case .speakingQuestion(let index):
            return "speakingQuestion_\(index)"
        case .listening:
            return "listening"
        case .evaluating:
            return "evaluating"
        case .speakingFeedback:
            return "speakingFeedback"
        case .awaitingNext:
            return "awaitingNext"
        case .complete:
            return "complete"
        case .error:
            return "error"
        }
    }
}

/// Errors that can occur during voice practice.
public enum VoicePracticeError: Error, Sendable, Equatable, LocalizedError {
    case microphoneUnavailable
    case microphonePermissionDenied
    case ttsUnavailable
    case transcriptionFailed(String)
    case evaluationFailed(String)
    case sessionInterrupted
    case noQuestionsAvailable

    public var errorDescription: String? {
        switch self {
        case .microphoneUnavailable:
            return "Microphone is not available"
        case .microphonePermissionDenied:
            return "Microphone permission was denied"
        case .ttsUnavailable:
            return "Text-to-speech is not available"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .evaluationFailed(let reason):
            return "Evaluation failed: \(reason)"
        case .sessionInterrupted:
            return "Session was interrupted"
        case .noQuestionsAvailable:
            return "No questions available for practice"
        }
    }
}

/// Voice commands for hands-free mode.
public enum VoiceCommand: String, CaseIterable, Sendable, Equatable {
    case next
    case `repeat`
    case explain
    case skip
    case stop

    public var variations: [String] {
        switch self {
        case .next:
            return ["next", "next question", "go ahead", "continue", "go on"]
        case .repeat:
            return ["repeat", "say again", "one more time", "again"]
        case .explain:
            return ["explain", "why", "tell me more", "help me understand"]
        case .skip:
            return ["skip", "pass", "move on", "next one"]
        case .stop:
            return ["stop", "end", "finish", "quit", "done", "exit"]
        }
    }

    public static func from(transcript: String) -> VoiceCommand? {
        let normalized = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        for command in VoiceCommand.allCases {
            for variation in command.variations where normalized.contains(variation) {
                return command
            }
        }

        return nil
    }

    public var confirmationMessage: String {
        switch self {
        case .next:
            return "Moving to next question"
        case .repeat:
            return "Repeating the question"
        case .explain:
            return "Let me explain"
        case .skip:
            return "Skipping this question"
        case .stop:
            return "Ending session"
        }
    }
}
