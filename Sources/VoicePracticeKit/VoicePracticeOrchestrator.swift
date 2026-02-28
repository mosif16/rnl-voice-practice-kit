import Foundation

/// Orchestrates voice practice state transitions and service coordination.
public actor VoicePracticeOrchestrator {
    public private(set) var state: VoicePracticeState = .idle
    public private(set) var session: VoicePracticeSession?
    public private(set) var currentTranscript: String = ""
    public private(set) var isInterrupted: Bool = false

    private let speechService: any VoicePracticeSpeechService
    private let inputService: any VoicePracticeInputService
    private let evaluator: any VoiceResponseEvaluating
    private let sessionStore: (any VoicePracticeSessionStore)?
    private let historyRecorder: (any VoicePracticeHistoryRecording)?
    private let rewarder: (any VoicePracticeRewarding)?
    private let logger: (any VoicePracticeLogging)?
    private let persistenceKey: String
    private let maxPersistedSessionAge: TimeInterval
    private let now: @Sendable () -> Date

    private var inputTask: Task<Void, Never>?
    private var questionStartTime: Date?
    private var stateBeforeInterruption: VoicePracticeState?
    private var transcriptBeforeInterruption: String?

    public init(
        speechService: any VoicePracticeSpeechService,
        inputService: any VoicePracticeInputService,
        evaluator: any VoiceResponseEvaluating,
        sessionStore: (any VoicePracticeSessionStore)? = nil,
        historyRecorder: (any VoicePracticeHistoryRecording)? = nil,
        rewarder: (any VoicePracticeRewarding)? = nil,
        logger: (any VoicePracticeLogging)? = nil,
        persistenceKey: String = "VoicePractice.SavedSession",
        maxPersistedSessionAge: TimeInterval = 30 * 60,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.speechService = speechService
        self.inputService = inputService
        self.evaluator = evaluator
        self.sessionStore = sessionStore
        self.historyRecorder = historyRecorder
        self.rewarder = rewarder
        self.logger = logger
        self.persistenceKey = persistenceKey
        self.maxPersistedSessionAge = maxPersistedSessionAge
        self.now = now
    }

    // MARK: - Session Lifecycle

    public func startSession(
        questions: [VoicePracticeQuestion],
        contentSource: ContentSource,
        settings: VoicePracticeSettings = .default
    ) async throws {
        guard !questions.isEmpty else {
            state = .error(.noQuestionsAvailable)
            throw VoicePracticeError.noQuestionsAvailable
        }

        guard await speechService.isAvailable() else {
            state = .error(.ttsUnavailable)
            throw VoicePracticeError.ttsUnavailable
        }

        guard await inputService.isMicrophoneAvailable() else {
            state = .error(.microphoneUnavailable)
            throw VoicePracticeError.microphoneUnavailable
        }

        let permissionGranted = await inputService.requestPermission()
        guard permissionGranted else {
            state = .error(.microphonePermissionDenied)
            throw VoicePracticeError.microphonePermissionDenied
        }

        session = VoicePracticeSession(
            contentSource: contentSource,
            questions: questions,
            settings: settings
        )

        await askNextQuestion()
    }

    public func endSession() async {
        await cancelInputTask()
        await speechService.stop()

        isInterrupted = false
        stateBeforeInterruption = nil
        transcriptBeforeInterruption = nil

        do {
            try await clearPersistedSession()
        } catch {
            await log("[VoicePractice] failed to clear persisted session: \(error)")
        }

        guard var currentSession = session else {
            state = .idle
            return
        }

        let summary = VoicePracticeSummary.from(questions: currentSession.questions)
        currentSession.endedAt = now()
        currentSession.summary = summary
        session = currentSession

        state = .complete(summary: summary)
        await rewarder?.awardXP(amount: summary.xpEarned, reason: "voice.practice.session.complete")
    }

    public func skipQuestion() async {
        guard var currentSession = session,
              let question = currentSession.currentQuestion else {
            return
        }

        await cancelInputTask()
        await speechService.stop()

        var skippedQuestion = question
        skippedQuestion.userTranscript = nil
        skippedQuestion.attemptedAt = now()
        if let questionStartTime {
            skippedQuestion.responseTime = now().timeIntervalSince(questionStartTime)
        }
        skippedQuestion.evaluation = VoiceResponseEvaluation(
            accuracyScore: 0,
            confidenceScore: 0,
            completenessScore: 0,
            keyPointsHit: [],
            keyPointsMissed: [],
            overallGrade: .noResponse
        )
        skippedQuestion.feedback = "Skipped"

        let questionIndex = currentSession.currentQuestionIndex
        currentSession.questions[questionIndex] = skippedQuestion
        session = currentSession

        await askNextQuestion()
    }

    public func repeatQuestion() async {
        guard let question = session?.currentQuestion else {
            return
        }

        await cancelInputTask()
        await speechService.stop()

        state = .speakingQuestion(index: session?.currentQuestionIndex ?? 0)
        questionStartTime = now()

        do {
            try await speechService.speak(question.question, settings: session?.settings ?? .default)
            await startListening()
        } catch {
            await log("[VoicePractice] failed to repeat question: \(error)")
            state = .error(.ttsUnavailable)
        }
    }

    public func nextQuestion() async {
        guard state == .awaitingNext else {
            return
        }
        await askNextQuestion()
    }

    // MARK: - Interruption Handling

    public func pauseForInterruption(persist: Bool = false) async {
        guard !isInterrupted, session != nil else {
            return
        }

        isInterrupted = true
        stateBeforeInterruption = state
        transcriptBeforeInterruption = currentTranscript

        await cancelInputTask()
        await speechService.stop()

        if persist {
            do {
                try await persistSessionState()
            } catch {
                await log("[VoicePractice] failed to persist interrupted session: \(error)")
            }
        }
    }

    public func resumeFromInterruption() async {
        guard isInterrupted, session != nil else {
            return
        }

        isInterrupted = false

        if let transcriptBeforeInterruption {
            currentTranscript = transcriptBeforeInterruption
        }

        guard let previousState = stateBeforeInterruption else {
            return
        }

        switch previousState {
        case .speakingQuestion(let index):
            state = .speakingQuestion(index: index)
            await repeatQuestion()
        case .listening:
            state = .listening(startTime: now())
            await startListening()
        case .awaitingNext:
            state = .awaitingNext
        case .evaluating:
            state = .listening(startTime: now())
            await startListening()
        case .speakingFeedback(let evaluation):
            if let feedback = session?.currentQuestion?.feedback {
                await speakFeedback(feedback: feedback, evaluation: evaluation)
            } else {
                state = .awaitingNext
            }
        case .idle, .complete, .error:
            state = previousState
        }

        stateBeforeInterruption = nil
        transcriptBeforeInterruption = nil
    }

    // MARK: - Persistence

    public func persistSessionState() async throws {
        guard let sessionStore, let currentSession = session else {
            return
        }
        try await sessionStore.save(session: currentSession, forKey: persistenceKey)
    }

    public func restorePersistedSession() async throws -> Bool {
        guard let sessionStore else {
            return false
        }

        guard let persistedSession = try await sessionStore.loadSession(forKey: persistenceKey) else {
            return false
        }

        let sessionAge = now().timeIntervalSince(persistedSession.startedAt)
        guard sessionAge < maxPersistedSessionAge else {
            try await sessionStore.clearSession(forKey: persistenceKey)
            return false
        }

        session = persistedSession
        state = .awaitingNext
        currentTranscript = ""
        return true
    }

    public func clearPersistedSession() async throws {
        guard let sessionStore else {
            return
        }
        try await sessionStore.clearSession(forKey: persistenceKey)
    }

    // MARK: - Voice Commands

    public func processVoiceCommand(_ command: VoiceCommand) async {
        guard session?.settings.handsFreeModeEnabled == true else {
            return
        }

        do {
            try await speechService.speak(command.confirmationMessage, settings: session?.settings ?? .default)
        } catch {
            await log("[VoicePractice] failed command confirmation: \(error)")
            state = .error(.ttsUnavailable)
            return
        }

        switch command {
        case .next:
            await nextQuestion()
        case .repeat:
            await repeatQuestion()
        case .skip:
            await skipQuestion()
        case .stop:
            await endSession()
        case .explain:
            await provideExplanation()
        }
    }

    // MARK: - State Machine

    private func askNextQuestion() async {
        guard let currentSession = session else {
            return
        }

        guard let question = currentSession.currentQuestion else {
            await endSession()
            return
        }

        let questionIndex = currentSession.currentQuestionIndex
        state = .speakingQuestion(index: questionIndex)
        questionStartTime = now()

        do {
            try await speechService.speak(question.question, settings: currentSession.settings)
            await startListening()
        } catch {
            await log("[VoicePractice] failed to speak question: \(error)")
            state = .error(.ttsUnavailable)
        }
    }

    private func startListening() async {
        guard session != nil else {
            return
        }

        state = .listening(startTime: now())
        currentTranscript = ""

        await cancelInputTask()

        let settings = session?.settings ?? .default
        let stream = await inputService.startListening(settings: settings)

        inputTask = Task {
            do {
                for try await event in stream {
                    await self.handleInputEvent(event)
                }
            } catch {
                await self.handleListeningFailure(error)
            }
            self.clearInputTaskIfCurrentTask()
        }
    }

    private func handleInputEvent(_ event: VoiceInputEvent) async {
        switch event {
        case .interimTranscript(let transcript):
            currentTranscript = transcript

        case .finalTranscript(let transcript):
            await inputService.cancelListening()
            await processResponse(transcript: transcript)

        case .silenceDetected:
            let transcript = await inputService.stopListening() ?? ""
            await processResponse(transcript: transcript)

        case .audioLevel:
            break

        case .error(let error):
            state = .error(.transcriptionFailed(error.localizedDescription))
        }
    }

    private func handleListeningFailure(_ error: Error) async {
        await log("[VoicePractice] listening failure: \(error)")
        state = .error(.transcriptionFailed(error.localizedDescription))
    }

    private func processResponse(transcript: String) async {
        guard var currentSession = session,
              var question = currentSession.currentQuestion else {
            return
        }

        state = .evaluating(transcript: transcript)
        currentTranscript = transcript

        if let questionStartTime {
            question.responseTime = now().timeIntervalSince(questionStartTime)
        }
        question.userTranscript = transcript
        question.attemptedAt = now()

        do {
            let evaluation = try await evaluator.evaluate(
                userTranscript: transcript,
                question: question.question,
                correctAnswer: question.correctAnswer
            )

            let feedback = try await evaluator.generateFeedback(
                for: evaluation,
                question: question.question,
                correctAnswer: question.correctAnswer
            )

            question.evaluation = evaluation
            question.feedback = feedback

            let questionIndex = currentSession.currentQuestionIndex
            currentSession.questions[questionIndex] = question
            session = currentSession

            await historyRecorder?.recordInteraction(
                question: question,
                transcript: transcript,
                evaluation: evaluation
            )

            await speakFeedback(feedback: feedback, evaluation: evaluation)
        } catch {
            await log("[VoicePractice] evaluation failed: \(error)")
            state = .error(.evaluationFailed(error.localizedDescription))
        }
    }

    private func speakFeedback(feedback: String, evaluation: VoiceResponseEvaluation) async {
        state = .speakingFeedback(evaluation: evaluation)

        do {
            try await speechService.speak(feedback, settings: session?.settings ?? .default)

            if session?.settings.autoAdvance == true {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await askNextQuestion()
            } else {
                state = .awaitingNext
            }
        } catch {
            await log("[VoicePractice] failed to speak feedback: \(error)")
            state = .error(.ttsUnavailable)
        }
    }

    private func provideExplanation() async {
        guard let question = session?.currentQuestion,
              let feedback = question.feedback else {
            return
        }

        do {
            try await speechService.speak(
                "Here is the explanation: \(feedback)",
                settings: session?.settings ?? .default
            )
        } catch {
            await log("[VoicePractice] failed to provide explanation: \(error)")
            state = .error(.ttsUnavailable)
        }
    }

    private func cancelInputTask() async {
        inputTask?.cancel()
        inputTask = nil
        await inputService.cancelListening()
    }

    private func clearInputTaskIfCurrentTask() {
        inputTask = nil
    }

    private func log(_ message: String) async {
        await logger?.log(message)
    }
}
