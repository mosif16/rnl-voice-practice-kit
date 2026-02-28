import Foundation

/// Deterministic keyword-based response evaluator.
public actor KeywordVoiceResponseEvaluator: VoiceResponseEvaluating {
    public init() {}

    public func evaluate(
        userTranscript: String,
        question: String,
        correctAnswer: String
    ) async throws -> VoiceResponseEvaluation {
        let normalizedTranscript = userTranscript.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedTranscript.isEmpty else {
            return VoiceResponseEvaluation(
                accuracyScore: 0,
                confidenceScore: 0,
                completenessScore: 0,
                keyPointsHit: [],
                keyPointsMissed: extractKeyPoints(from: correctAnswer),
                overallGrade: .noResponse
            )
        }

        let userWords = tokenize(normalizedTranscript)
        let correctKeywords = extractKeyPoints(from: correctAnswer)
        let keywordSet = Set(correctKeywords.map { $0.lowercased() })

        let matched = userWords.intersection(keywordSet)
        let accuracyScore = correctKeywords.isEmpty ? 0 : Float(matched.count) / Float(correctKeywords.count)

        let fillerWords = ["um", "uh", "like", "you know", "basically", "actually", "so", "well"]
        let loweredTranscript = normalizedTranscript.lowercased()
        let detectedFillers = fillerWords.filter { loweredTranscript.contains($0) }
        let confidenceScore = max(0, 1.0 - Float(detectedFillers.count) * 0.1)

        let keyPointsHit = correctKeywords.filter { matched.contains($0.lowercased()) }
        let keyPointsMissed = correctKeywords.filter { !matched.contains($0.lowercased()) }

        return VoiceResponseEvaluation(
            accuracyScore: accuracyScore,
            confidenceScore: confidenceScore,
            completenessScore: accuracyScore,
            keyPointsHit: keyPointsHit,
            keyPointsMissed: keyPointsMissed,
            fillerWordsDetected: detectedFillers,
            overallGrade: ResponseGrade.from(accuracy: accuracyScore, confidence: confidenceScore)
        )
    }

    public func generateFeedback(
        for evaluation: VoiceResponseEvaluation,
        question: String,
        correctAnswer: String
    ) async throws -> String {
        switch evaluation.overallGrade {
        case .excellent:
            return "Excellent. That is exactly right."
        case .good:
            return "Good job. You covered the main points."
        case .partial:
            if evaluation.keyPointsMissed.isEmpty {
                return "You are on the right track. The complete answer is: \(correctAnswer)"
            }
            return "Partially correct. You missed: \(evaluation.keyPointsMissed.joined(separator: ", ")). The answer is: \(correctAnswer)"
        case .incorrect:
            return "Not quite. The correct answer is: \(correctAnswer)"
        case .noResponse:
            return "I did not hear a response. The answer is: \(correctAnswer)"
        }
    }

    private func tokenize(_ text: String) -> Set<String> {
        Set(
            text.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { !$0.isEmpty }
        )
    }

    private func extractKeyPoints(from answer: String) -> [String] {
        var seen = Set<String>()
        var keyPoints: [String] = []

        let words = answer
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }

        for word in words {
            let lowered = word.lowercased()
            guard word.count > 3, !isCommonWord(lowered) else {
                continue
            }
            if seen.insert(lowered).inserted {
                keyPoints.append(word)
            }
        }

        return keyPoints
    }

    private func isCommonWord(_ word: String) -> Bool {
        let commonWords: Set<String> = [
            "the", "and", "for", "are", "but", "not", "you", "all",
            "can", "had", "her", "was", "one", "our", "out", "has",
            "have", "been", "this", "that", "they", "what", "with",
            "when", "where", "which", "their", "there", "these", "those",
            "from", "will", "would", "could", "should", "about", "into",
            "also", "than", "then", "very", "just", "because", "being"
        ]
        return commonWords.contains(word)
    }
}
