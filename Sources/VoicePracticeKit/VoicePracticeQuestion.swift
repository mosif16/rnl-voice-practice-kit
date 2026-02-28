import Foundation

/// Flashcard-like source that can produce a voice practice question.
public protocol VoicePracticeFlashcardSource: Sendable {
    var id: UUID { get }
    var question: String { get }
    var answer: String { get }
}

/// Quiz-question-like source that can produce a voice practice question.
public protocol VoicePracticeQuizQuestionSource: Sendable {
    var id: UUID { get }
    var question: String { get }
    var options: [String] { get }
    var correctAnswerIndex: Int { get }
}

/// Represents a single question-answer pair in a voice practice session.
public struct VoicePracticeQuestion: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let question: String
    public let correctAnswer: String
    public let sourceID: UUID
    public let sourceType: SourceType

    public var userTranscript: String?
    public var evaluation: VoiceResponseEvaluation?
    public var feedback: String?
    public var attemptedAt: Date?
    public var responseTime: TimeInterval?

    public init(
        id: UUID = UUID(),
        question: String,
        correctAnswer: String,
        sourceID: UUID,
        sourceType: SourceType,
        userTranscript: String? = nil,
        evaluation: VoiceResponseEvaluation? = nil,
        feedback: String? = nil,
        attemptedAt: Date? = nil,
        responseTime: TimeInterval? = nil
    ) {
        self.id = id
        self.question = question
        self.correctAnswer = correctAnswer
        self.sourceID = sourceID
        self.sourceType = sourceType
        self.userTranscript = userTranscript
        self.evaluation = evaluation
        self.feedback = feedback
        self.attemptedAt = attemptedAt
        self.responseTime = responseTime
    }

    public var isAnswered: Bool {
        evaluation != nil
    }

    public var isCorrect: Bool {
        guard let evaluation else { return false }
        return evaluation.isCorrect
    }

    public enum SourceType: String, Codable, Sendable, Hashable {
        case flashcard
        case quizQuestion
    }
}

extension VoicePracticeQuestion {
    /// Create a voice practice question from a flashcard source.
    public static func from<Source: VoicePracticeFlashcardSource>(flashcard: Source) -> VoicePracticeQuestion {
        VoicePracticeQuestion(
            question: flashcard.question,
            correctAnswer: flashcard.answer,
            sourceID: flashcard.id,
            sourceType: .flashcard
        )
    }

    /// Create a voice practice question from a quiz question source.
    public static func from<Source: VoicePracticeQuizQuestionSource>(quizQuestion: Source) -> VoicePracticeQuestion {
        let correctAnswer = quizQuestion.options.indices.contains(quizQuestion.correctAnswerIndex)
            ? quizQuestion.options[quizQuestion.correctAnswerIndex]
            : ""

        return VoicePracticeQuestion(
            question: quizQuestion.question,
            correctAnswer: correctAnswer,
            sourceID: quizQuestion.id,
            sourceType: .quizQuestion
        )
    }
}
