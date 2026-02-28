import XCTest
@testable import VoicePracticeKit

final class VoicePracticeOrchestratorTests: XCTestCase {
    func testStartSessionWithNoQuestionsThrows() async {
        let speech = MockSpeechService()
        let input = MockInputService()
        let evaluator = MockEvaluator()
        let orchestrator = VoicePracticeOrchestrator(
            speechService: speech,
            inputService: input,
            evaluator: evaluator
        )

        do {
            try await orchestrator.startSession(
                questions: [],
                contentSource: .weakCards,
                settings: .default
            )
            XCTFail("Expected startSession to throw")
        } catch let error as VoicePracticeError {
            XCTAssertEqual(error, .noQuestionsAvailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let state = await orchestrator.state
        guard case .error(let error) = state else {
            XCTFail("Expected error state")
            return
        }
        XCTAssertEqual(error, .noQuestionsAvailable)
    }

    func testHappyPathTransitionsToAwaitingNextAndStoresEvaluation() async throws {
        let speech = MockSpeechService()
        let input = MockInputService()
        let evaluator = MockEvaluator()
        let history = MockHistoryRecorder()

        let orchestrator = VoicePracticeOrchestrator(
            speechService: speech,
            inputService: input,
            evaluator: evaluator,
            historyRecorder: history
        )

        let question = VoicePracticeQuestion(
            question: "What powers a cell?",
            correctAnswer: "Mitochondria",
            sourceID: UUID(),
            sourceType: .flashcard
        )

        var settings = VoicePracticeSettings.default
        settings.autoAdvance = false

        try await orchestrator.startSession(
            questions: [question],
            contentSource: .weakCards,
            settings: settings
        )

        try await waitForState("listening", in: orchestrator)

        await input.emit(.finalTranscript("mitochondria"))

        try await waitForState("awaitingNext", in: orchestrator)

        let session = await orchestrator.session
        XCTAssertNotNil(session?.questions.first?.evaluation)
        XCTAssertEqual(session?.questions.first?.feedback, MockEvaluator.defaultFeedback)

        let spokenTexts = await speech.spokenTexts()
        XCTAssertEqual(spokenTexts.count, 2)
        XCTAssertEqual(spokenTexts.first, "What powers a cell?")
        XCTAssertEqual(spokenTexts.last, MockEvaluator.defaultFeedback)

        let records = await history.records()
        XCTAssertEqual(records.count, 1)

        await orchestrator.endSession()
    }

    func testAutoAdvanceCompletesSession() async throws {
        let speech = MockSpeechService()
        let input = MockInputService()
        let evaluator = MockEvaluator()

        let orchestrator = VoicePracticeOrchestrator(
            speechService: speech,
            inputService: input,
            evaluator: evaluator
        )

        let question = VoicePracticeQuestion(
            question: "What powers a cell?",
            correctAnswer: "Mitochondria",
            sourceID: UUID(),
            sourceType: .flashcard
        )

        var settings = VoicePracticeSettings.default
        settings.autoAdvance = true

        try await orchestrator.startSession(
            questions: [question],
            contentSource: .weakCards,
            settings: settings
        )

        try await waitForState("listening", in: orchestrator)
        await input.emit(.finalTranscript("mitochondria"))
        try await waitForState("complete", in: orchestrator)

        let session = await orchestrator.session
        XCTAssertNotNil(session?.summary)
        XCTAssertEqual(session?.summary?.questionsAnswered, 1)
    }

    func testPauseAndResumeRestoresListeningState() async throws {
        let speech = MockSpeechService()
        let input = MockInputService()
        let evaluator = MockEvaluator()

        let orchestrator = VoicePracticeOrchestrator(
            speechService: speech,
            inputService: input,
            evaluator: evaluator
        )

        let question = VoicePracticeQuestion(
            question: "What powers a cell?",
            correctAnswer: "Mitochondria",
            sourceID: UUID(),
            sourceType: .flashcard
        )

        var settings = VoicePracticeSettings.default
        settings.autoAdvance = false

        try await orchestrator.startSession(
            questions: [question],
            contentSource: .weakCards,
            settings: settings
        )

        try await waitForState("listening", in: orchestrator)

        await orchestrator.pauseForInterruption()
        let interruptedAfterPause = await orchestrator.isInterrupted
        XCTAssertTrue(interruptedAfterPause)

        await orchestrator.resumeFromInterruption()

        try await waitForState("listening", in: orchestrator)
        let interruptedAfterResume = await orchestrator.isInterrupted
        XCTAssertFalse(interruptedAfterResume)

        await orchestrator.endSession()
    }

    func testRestorePersistedSession() async throws {
        let speech = MockSpeechService()
        let input = MockInputService()
        let evaluator = MockEvaluator()
        let store = InMemoryVoicePracticeSessionStore()

        let persistenceKey = "VoicePractice.SavedSession.Tests"

        let first = VoicePracticeOrchestrator(
            speechService: speech,
            inputService: input,
            evaluator: evaluator,
            sessionStore: store,
            persistenceKey: persistenceKey
        )

        let question = VoicePracticeQuestion(
            question: "What powers a cell?",
            correctAnswer: "Mitochondria",
            sourceID: UUID(),
            sourceType: .flashcard
        )

        try await first.startSession(
            questions: [question],
            contentSource: .weakCards,
            settings: .default
        )
        try await first.persistSessionState()

        let second = VoicePracticeOrchestrator(
            speechService: speech,
            inputService: input,
            evaluator: evaluator,
            sessionStore: store,
            persistenceKey: persistenceKey
        )

        let restored = try await second.restorePersistedSession()
        XCTAssertTrue(restored)
        let restoredState = await second.state.stateIdentifier
        XCTAssertEqual(restoredState, "awaitingNext")
    }

    private func waitForState(
        _ stateIdentifier: String,
        in orchestrator: VoicePracticeOrchestrator,
        timeout: TimeInterval = 2.0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let timeoutDate = Date().addingTimeInterval(timeout)

        while Date() < timeoutDate {
            let current = await orchestrator.state.stateIdentifier
            if current == stateIdentifier {
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        let finalState = await orchestrator.state.stateIdentifier
        XCTFail("Timed out waiting for state \(stateIdentifier). Final state: \(finalState)", file: file, line: line)
    }
}

private actor MockSpeechService: VoicePracticeSpeechService {
    private var available = true
    private var shouldThrow = false
    private var spoken: [String] = []

    func isAvailable() async -> Bool {
        available
    }

    func speak(_ text: String, settings: VoicePracticeSettings) async throws {
        if shouldThrow {
            throw MockError.speechFailure
        }
        spoken.append(text)
    }

    func stop() async {}

    func spokenTexts() -> [String] {
        spoken
    }

    func setAvailable(_ available: Bool) {
        self.available = available
    }

    func setShouldThrow(_ shouldThrow: Bool) {
        self.shouldThrow = shouldThrow
    }

    private enum MockError: Error {
        case speechFailure
    }
}

private actor MockInputService: VoicePracticeInputService {
    private var microphoneAvailable = true
    private var permissionGranted = true
    private var continuation: AsyncThrowingStream<VoiceInputEvent, Error>.Continuation?

    func isMicrophoneAvailable() async -> Bool {
        microphoneAvailable
    }

    func requestPermission() async -> Bool {
        permissionGranted
    }

    func startListening(settings: VoicePracticeSettings) async -> AsyncThrowingStream<VoiceInputEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.setContinuation(continuation)
            }
        }
    }

    func stopListening() async -> String? {
        continuation?.finish()
        continuation = nil
        return ""
    }

    func cancelListening() async {
        continuation?.finish()
        continuation = nil
    }

    func emit(_ event: VoiceInputEvent) {
        continuation?.yield(event)
    }

    func setMicrophoneAvailable(_ value: Bool) {
        microphoneAvailable = value
    }

    func setPermissionGranted(_ value: Bool) {
        permissionGranted = value
    }

    private func setContinuation(_ continuation: AsyncThrowingStream<VoiceInputEvent, Error>.Continuation) async {
        self.continuation = continuation
    }
}

private actor MockEvaluator: VoiceResponseEvaluating {
    static let defaultFeedback = "Good job. You covered the main points."

    private let evaluation = VoiceResponseEvaluation(
        accuracyScore: 1.0,
        confidenceScore: 1.0,
        completenessScore: 1.0,
        keyPointsHit: ["Mitochondria"],
        keyPointsMissed: [],
        overallGrade: .excellent
    )

    func evaluate(
        userTranscript: String,
        question: String,
        correctAnswer: String
    ) async throws -> VoiceResponseEvaluation {
        evaluation
    }

    func generateFeedback(
        for evaluation: VoiceResponseEvaluation,
        question: String,
        correctAnswer: String
    ) async throws -> String {
        Self.defaultFeedback
    }
}

private actor MockHistoryRecorder: VoicePracticeHistoryRecording {
    private var storage: [VoiceResponseEvaluation] = []

    func recordInteraction(
        question: VoicePracticeQuestion,
        transcript: String,
        evaluation: VoiceResponseEvaluation
    ) async {
        storage.append(evaluation)
    }

    func records() -> [VoiceResponseEvaluation] {
        storage
    }
}
