import Foundation

/// Represents a single voice practice session.
public struct VoicePracticeSession: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let startedAt: Date
    public var endedAt: Date?
    public let contentSource: ContentSource
    public var questions: [VoicePracticeQuestion]
    public var settings: VoicePracticeSettings
    public var summary: VoicePracticeSummary?

    public init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        contentSource: ContentSource,
        questions: [VoicePracticeQuestion],
        settings: VoicePracticeSettings = .default
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.contentSource = contentSource
        self.questions = questions
        self.settings = settings
    }

    public var isComplete: Bool {
        endedAt != nil
    }

    public var questionsAnswered: Int {
        questions.filter { $0.evaluation != nil }.count
    }

    public var currentQuestionIndex: Int {
        questionsAnswered
    }

    public var currentQuestion: VoicePracticeQuestion? {
        guard currentQuestionIndex < questions.count else {
            return nil
        }
        return questions[currentQuestionIndex]
    }

    public var hasMoreQuestions: Bool {
        currentQuestionIndex < questions.count
    }

    public var duration: TimeInterval {
        let endTime = endedAt ?? Date()
        return endTime.timeIntervalSince(startedAt)
    }
}

/// Source of questions for voice practice.
public enum ContentSource: Codable, Sendable, Hashable {
    case flashcardDeck(id: UUID, name: String)
    case quiz(id: UUID, name: String)
    case weakCards

    public var displayName: String {
        switch self {
        case .flashcardDeck(_, let name):
            return name
        case .quiz(_, let name):
            return name
        case .weakCards:
            return "Weak Cards"
        }
    }

    public var sourceID: UUID? {
        switch self {
        case .flashcardDeck(let id, _), .quiz(let id, _):
            return id
        case .weakCards:
            return nil
        }
    }
}
