import XCTest
@testable import VoicePracticeKit

final class VoicePracticeStateTests: XCTestCase {
    private func makeEvaluation(
        accuracy: Float = 0.8,
        confidence: Float = 0.9,
        completeness: Float = 0.7,
        grade: ResponseGrade = .good
    ) -> VoiceResponseEvaluation {
        VoiceResponseEvaluation(
            accuracyScore: accuracy,
            confidenceScore: confidence,
            completenessScore: completeness,
            keyPointsHit: ["mitochondria"],
            keyPointsMissed: ["ATP"],
            overallGrade: grade
        )
    }

    private func makeSummary() -> VoicePracticeSummary {
        VoicePracticeSummary(
            totalQuestions: 5,
            questionsAnswered: 4,
            averageAccuracy: 0.75,
            averageConfidence: 0.8,
            averageResponseTime: 3.2,
            gradeDistribution: [.excellent: 1, .good: 2, .partial: 1],
            mostMissedTopics: ["ATP", "glucose"],
            xpEarned: 90
        )
    }

    private func makeQuestion(
        question: String = "What is the powerhouse of the cell?",
        answer: String = "Mitochondria",
        evaluated: Bool = false
    ) -> VoicePracticeQuestion {
        var value = VoicePracticeQuestion(
            question: question,
            correctAnswer: answer,
            sourceID: UUID(),
            sourceType: .flashcard
        )

        if evaluated {
            value.evaluation = makeEvaluation()
            value.feedback = "Good job"
            value.attemptedAt = Date()
            value.responseTime = 2.5
        }

        return value
    }

    private func makeSession(questionCount: Int = 5, answeredCount: Int = 0) -> VoicePracticeSession {
        var questions: [VoicePracticeQuestion] = []
        for index in 0..<questionCount {
            questions.append(
                makeQuestion(
                    question: "Question \(index + 1)?",
                    answer: "Answer \(index + 1)",
                    evaluated: index < answeredCount
                )
            )
        }

        return VoicePracticeSession(contentSource: .weakCards, questions: questions)
    }

    func testIdleNotActive() {
        let state = VoicePracticeState.idle
        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isSpeaking)
        XCTAssertFalse(state.isListening)
    }

    func testSpeakingQuestionIsActive() {
        let state = VoicePracticeState.speakingQuestion(index: 0)
        XCTAssertTrue(state.isActive)
        XCTAssertTrue(state.isSpeaking)
        XCTAssertFalse(state.isListening)
    }

    func testListeningIsActive() {
        let state = VoicePracticeState.listening(startTime: Date())
        XCTAssertTrue(state.isActive)
        XCTAssertFalse(state.isSpeaking)
        XCTAssertTrue(state.isListening)
    }

    func testEvaluatingIsActive() {
        let state = VoicePracticeState.evaluating(transcript: "mitochondria")
        XCTAssertTrue(state.isActive)
        XCTAssertFalse(state.isSpeaking)
        XCTAssertFalse(state.isListening)
    }

    func testSpeakingFeedbackIsActive() {
        let state = VoicePracticeState.speakingFeedback(evaluation: makeEvaluation())
        XCTAssertTrue(state.isActive)
        XCTAssertTrue(state.isSpeaking)
        XCTAssertFalse(state.isListening)
    }

    func testCompleteNotActive() {
        let state = VoicePracticeState.complete(summary: makeSummary())
        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.isSpeaking)
        XCTAssertFalse(state.isListening)
    }

    func testErrorNotActive() {
        let state = VoicePracticeState.error(.microphoneUnavailable)
        XCTAssertFalse(state.isActive)
    }

    func testAwaitingNextIsActive() {
        let state = VoicePracticeState.awaitingNext
        XCTAssertTrue(state.isActive)
        XCTAssertFalse(state.isSpeaking)
        XCTAssertFalse(state.isListening)
    }

    func testDisplayTextNonEmpty() {
        let states: [VoicePracticeState] = [
            .idle,
            .speakingQuestion(index: 0),
            .listening(startTime: Date()),
            .evaluating(transcript: "test"),
            .speakingFeedback(evaluation: makeEvaluation()),
            .awaitingNext,
            .complete(summary: makeSummary()),
            .error(.noQuestionsAvailable)
        ]

        for state in states {
            XCTAssertFalse(state.displayText.isEmpty, "\(state.stateIdentifier) should have display text")
        }
    }

    func testSpeakingQuestionDisplayIndexUsesOneBasedIndex() {
        let state = VoicePracticeState.speakingQuestion(index: 2)
        XCTAssertTrue(state.displayText.contains("3"))
    }

    func testStateIdentifiersAreUnique() {
        let identifiers = [
            VoicePracticeState.idle.stateIdentifier,
            VoicePracticeState.speakingQuestion(index: 0).stateIdentifier,
            VoicePracticeState.listening(startTime: Date()).stateIdentifier,
            VoicePracticeState.evaluating(transcript: "t").stateIdentifier,
            VoicePracticeState.speakingFeedback(evaluation: makeEvaluation()).stateIdentifier,
            VoicePracticeState.awaitingNext.stateIdentifier,
            VoicePracticeState.complete(summary: makeSummary()).stateIdentifier,
            VoicePracticeState.error(.ttsUnavailable).stateIdentifier
        ]

        XCTAssertEqual(Set(identifiers).count, identifiers.count)
    }

    func testSpeakingQuestionIdentifiersDifferByIndex() {
        let first = VoicePracticeState.speakingQuestion(index: 0).stateIdentifier
        let second = VoicePracticeState.speakingQuestion(index: 1).stateIdentifier
        XCTAssertNotEqual(first, second)
    }

    func testSessionQuestionsAnswered() {
        let session = makeSession(questionCount: 5, answeredCount: 3)
        XCTAssertEqual(session.questionsAnswered, 3)
        XCTAssertEqual(session.currentQuestionIndex, 3)
        XCTAssertTrue(session.hasMoreQuestions)
    }

    func testSessionCompletionDetection() {
        let session = makeSession(questionCount: 3, answeredCount: 3)
        XCTAssertEqual(session.questionsAnswered, 3)
        XCTAssertFalse(session.hasMoreQuestions)
        XCTAssertNil(session.currentQuestion)
    }

    func testNewSessionNotComplete() {
        let session = makeSession()
        XCTAssertFalse(session.isComplete)
        XCTAssertNil(session.endedAt)
    }

    func testSessionWithEndedAtIsComplete() {
        var session = makeSession()
        session.endedAt = Date()
        XCTAssertTrue(session.isComplete)
    }

    func testSessionDuration() {
        let startTime = Date().addingTimeInterval(-300)
        let session = VoicePracticeSession(
            startedAt: startTime,
            contentSource: .weakCards,
            questions: [makeQuestion()]
        )

        XCTAssertGreaterThanOrEqual(session.duration, 299)
        XCTAssertLessThanOrEqual(session.duration, 301)
    }

    func testVoiceCommandMatching() {
        XCTAssertEqual(VoiceCommand.from(transcript: "next question"), .next)
        XCTAssertEqual(VoiceCommand.from(transcript: "say again"), .repeat)
        XCTAssertEqual(VoiceCommand.from(transcript: "tell me more"), .explain)
        XCTAssertEqual(VoiceCommand.from(transcript: "skip"), .skip)
        XCTAssertEqual(VoiceCommand.from(transcript: "I'm done"), .stop)
    }

    func testUnrecognizedCommandReturnsNil() {
        XCTAssertNil(VoiceCommand.from(transcript: "banana"))
        XCTAssertNil(VoiceCommand.from(transcript: ""))
    }

    func testVoiceCommandMatchingIsCaseInsensitive() {
        XCTAssertEqual(VoiceCommand.from(transcript: "NEXT"), .next)
        XCTAssertEqual(VoiceCommand.from(transcript: "Stop"), .stop)
        XCTAssertEqual(VoiceCommand.from(transcript: "SKIP"), .skip)
    }

    func testCommandConfirmationMessagesNonEmpty() {
        for command in VoiceCommand.allCases {
            XCTAssertFalse(command.confirmationMessage.isEmpty)
        }
    }

    func testErrorDescriptionsNonEmpty() {
        let errors: [VoicePracticeError] = [
            .microphoneUnavailable,
            .microphonePermissionDenied,
            .ttsUnavailable,
            .transcriptionFailed("timeout"),
            .evaluationFailed("model error"),
            .sessionInterrupted,
            .noQuestionsAvailable
        ]

        for error in errors {
            XCTAssertFalse((error.errorDescription ?? "").isEmpty)
        }
    }

    func testTranscriptionErrorContainsReason() {
        let error = VoicePracticeError.transcriptionFailed("network timeout")
        XCTAssertTrue(error.errorDescription?.contains("network timeout") == true)
    }

    func testUnansweredQuestionFlags() {
        let question = makeQuestion(evaluated: false)
        XCTAssertFalse(question.isAnswered)
        XCTAssertFalse(question.isCorrect)
    }

    func testAnsweredQuestionFlags() {
        let question = makeQuestion(evaluated: true)
        XCTAssertTrue(question.isAnswered)
        XCTAssertTrue(question.isCorrect)
    }
}
