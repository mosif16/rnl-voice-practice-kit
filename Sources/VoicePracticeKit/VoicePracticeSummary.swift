import Foundation

/// Aggregated metrics for a completed voice practice session.
public struct VoicePracticeSummary: Codable, Sendable, Hashable {
    public let totalQuestions: Int
    public let questionsAnswered: Int
    public let averageAccuracy: Float
    public let averageConfidence: Float
    public let averageResponseTime: TimeInterval
    public let gradeDistribution: [ResponseGrade: Int]
    public let mostMissedTopics: [String]
    public let xpEarned: Int

    public init(
        totalQuestions: Int,
        questionsAnswered: Int,
        averageAccuracy: Float,
        averageConfidence: Float,
        averageResponseTime: TimeInterval,
        gradeDistribution: [ResponseGrade: Int],
        mostMissedTopics: [String],
        xpEarned: Int
    ) {
        self.totalQuestions = totalQuestions
        self.questionsAnswered = questionsAnswered
        self.averageAccuracy = averageAccuracy
        self.averageConfidence = averageConfidence
        self.averageResponseTime = averageResponseTime
        self.gradeDistribution = gradeDistribution
        self.mostMissedTopics = mostMissedTopics
        self.xpEarned = xpEarned
    }

    public var completionRate: Float {
        guard totalQuestions > 0 else { return 0 }
        return Float(questionsAnswered) / Float(totalQuestions)
    }

    public var completionPercentage: String {
        "\(Int(completionRate * 100))%"
    }

    public var accuracyPercentage: String {
        "\(Int(averageAccuracy * 100))%"
    }

    public var confidencePercentage: String {
        "\(Int(averageConfidence * 100))%"
    }

    public var formattedResponseTime: String {
        String(format: "%.1fs", averageResponseTime)
    }

    public var excellentCount: Int {
        gradeDistribution[.excellent] ?? 0
    }

    public var goodCount: Int {
        gradeDistribution[.good] ?? 0
    }

    public var partialCount: Int {
        gradeDistribution[.partial] ?? 0
    }

    public var incorrectCount: Int {
        gradeDistribution[.incorrect] ?? 0
    }

    public static func from(questions: [VoicePracticeQuestion]) -> VoicePracticeSummary {
        let answeredQuestions = questions.filter { $0.evaluation != nil }
        let evaluations = answeredQuestions.compactMap(\.evaluation)

        let totalAccuracy = evaluations.reduce(0.0) { $0 + $1.accuracyScore }
        let totalConfidence = evaluations.reduce(0.0) { $0 + $1.confidenceScore }
        let totalResponseTime = answeredQuestions.compactMap(\.responseTime).reduce(0.0, +)

        let averageAccuracy = evaluations.isEmpty ? 0 : totalAccuracy / Float(evaluations.count)
        let averageConfidence = evaluations.isEmpty ? 0 : totalConfidence / Float(evaluations.count)
        let averageResponseTime = answeredQuestions.isEmpty ? 0 : totalResponseTime / Double(answeredQuestions.count)

        var gradeDistribution: [ResponseGrade: Int] = [:]
        for evaluation in evaluations {
            gradeDistribution[evaluation.overallGrade, default: 0] += 1
        }

        var missedTopicCounts: [String: Int] = [:]
        for evaluation in evaluations {
            for topic in evaluation.keyPointsMissed {
                missedTopicCounts[topic, default: 0] += 1
            }
        }

        let mostMissedTopics = missedTopicCounts
            .sorted { left, right in
                if left.value == right.value {
                    return left.key < right.key
                }
                return left.value > right.value
            }
            .prefix(5)
            .map(\.key)

        let baseXP = answeredQuestions.count * 10
        let excellentBonus = (gradeDistribution[.excellent] ?? 0) * 5
        let completionBonus = questions.count == answeredQuestions.count ? 50 : 0

        return VoicePracticeSummary(
            totalQuestions: questions.count,
            questionsAnswered: answeredQuestions.count,
            averageAccuracy: averageAccuracy,
            averageConfidence: averageConfidence,
            averageResponseTime: averageResponseTime,
            gradeDistribution: gradeDistribution,
            mostMissedTopics: mostMissedTopics,
            xpEarned: baseXP + excellentBonus + completionBonus
        )
    }
}
