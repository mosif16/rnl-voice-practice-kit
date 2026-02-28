import Foundation

/// Scoring breakdown for a single verbal response.
public struct VoiceResponseEvaluation: Codable, Sendable, Hashable {
    /// Accuracy score (0.0 - 1.0) based on content correctness.
    public let accuracyScore: Float

    /// Confidence score (0.0 - 1.0) based on fluency and hesitation markers.
    public let confidenceScore: Float

    /// Completeness score (0.0 - 1.0) for multi-part answers.
    public let completenessScore: Float

    /// Key concepts that were correctly mentioned.
    public let keyPointsHit: [String]

    /// Key concepts that were missed.
    public let keyPointsMissed: [String]

    /// Additional relevant concepts mentioned (extra credit).
    public let bonusConceptsMentioned: [String]

    /// Filler words detected in the response.
    public let fillerWordsDetected: [String]

    /// Overall grade for the response.
    public let overallGrade: ResponseGrade

    public init(
        accuracyScore: Float,
        confidenceScore: Float,
        completenessScore: Float,
        keyPointsHit: [String],
        keyPointsMissed: [String],
        bonusConceptsMentioned: [String] = [],
        fillerWordsDetected: [String] = [],
        overallGrade: ResponseGrade
    ) {
        self.accuracyScore = min(1.0, max(0.0, accuracyScore))
        self.confidenceScore = min(1.0, max(0.0, confidenceScore))
        self.completenessScore = min(1.0, max(0.0, completenessScore))
        self.keyPointsHit = keyPointsHit
        self.keyPointsMissed = keyPointsMissed
        self.bonusConceptsMentioned = bonusConceptsMentioned
        self.fillerWordsDetected = fillerWordsDetected
        self.overallGrade = overallGrade
    }

    /// Whether the response is considered correct.
    public var isCorrect: Bool {
        overallGrade != .incorrect && overallGrade != .noResponse
    }

    /// Combined weighted score.
    public var combinedScore: Float {
        (accuracyScore * 0.6) + (confidenceScore * 0.2) + (completenessScore * 0.2)
    }

    public var accuracyPercentage: String {
        "\(Int(accuracyScore * 100))%"
    }

    public var confidencePercentage: String {
        "\(Int(confidenceScore * 100))%"
    }
}

/// Overall grade for a verbal response.
public enum ResponseGrade: String, Codable, Sendable, CaseIterable, Hashable {
    case excellent
    case good
    case partial
    case incorrect
    case noResponse

    public var displayName: String {
        switch self {
        case .excellent:
            return "Excellent!"
        case .good:
            return "Good!"
        case .partial:
            return "Partial"
        case .incorrect:
            return "Not quite"
        case .noResponse:
            return "No response"
        }
    }

    /// Calculate grade from accuracy and confidence scores.
    public static func from(accuracy: Float, confidence: Float) -> ResponseGrade {
        if accuracy >= 0.9 && confidence >= 0.7 {
            return .excellent
        }
        if accuracy >= 0.7 {
            return .good
        }
        if accuracy >= 0.4 {
            return .partial
        }
        if accuracy > 0 {
            return .incorrect
        }
        return .noResponse
    }
}
