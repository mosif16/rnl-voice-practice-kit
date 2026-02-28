import XCTest
@testable import VoicePracticeKit

final class KeywordVoiceResponseEvaluatorTests: XCTestCase {
    func testEmptyTranscriptReturnsNoResponse() async throws {
        let evaluator = KeywordVoiceResponseEvaluator()

        let result = try await evaluator.evaluate(
            userTranscript: "   ",
            question: "What powers a cell?",
            correctAnswer: "Mitochondria produce ATP"
        )

        XCTAssertEqual(result.overallGrade, .noResponse)
        XCTAssertEqual(result.accuracyScore, 0)
        XCTAssertEqual(result.confidenceScore, 0)
        XCTAssertFalse(result.keyPointsMissed.isEmpty)
    }

    func testKeywordMatchingProducesExpectedScores() async throws {
        let evaluator = KeywordVoiceResponseEvaluator()

        let result = try await evaluator.evaluate(
            userTranscript: "Mitochondria produce ATP for the cell",
            question: "What powers a cell?",
            correctAnswer: "Mitochondria produce ATP"
        )

        XCTAssertGreaterThanOrEqual(result.accuracyScore, 0.66)
        XCTAssertEqual(result.confidenceScore, 1.0)
        XCTAssertTrue(result.keyPointsHit.contains("Mitochondria"))
        XCTAssertNotEqual(result.overallGrade, .noResponse)
    }

    func testFillerWordsReduceConfidence() async throws {
        let evaluator = KeywordVoiceResponseEvaluator()

        let result = try await evaluator.evaluate(
            userTranscript: "Um like mitochondria, you know, produce ATP",
            question: "What powers a cell?",
            correctAnswer: "Mitochondria produce ATP"
        )

        XCTAssertLessThan(result.confidenceScore, 1.0)
        XCTAssertFalse(result.fillerWordsDetected.isEmpty)
    }

    func testGenerateFeedbackForPartialIncludesMissedTopics() async throws {
        let evaluator = KeywordVoiceResponseEvaluator()
        let evaluation = VoiceResponseEvaluation(
            accuracyScore: 0.5,
            confidenceScore: 0.8,
            completenessScore: 0.5,
            keyPointsHit: ["Mitochondria"],
            keyPointsMissed: ["ATP"],
            overallGrade: .partial
        )

        let feedback = try await evaluator.generateFeedback(
            for: evaluation,
            question: "What powers a cell?",
            correctAnswer: "Mitochondria produce ATP"
        )

        XCTAssertTrue(feedback.contains("missed"))
        XCTAssertTrue(feedback.contains("ATP"))
    }
}
