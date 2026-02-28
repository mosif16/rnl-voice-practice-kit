import Foundation

/// `UserDefaults` implementation for persisted voice practice sessions.
public actor UserDefaultsVoicePracticeSessionStore: VoicePracticeSessionStore {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        defaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.defaults = defaults
        self.encoder = encoder
        self.decoder = decoder
    }

    public func save(session: VoicePracticeSession, forKey key: String) async throws {
        let data = try encoder.encode(session)
        defaults.set(data, forKey: key)
    }

    public func loadSession(forKey key: String) async throws -> VoicePracticeSession? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try decoder.decode(VoicePracticeSession.self, from: data)
    }

    public func clearSession(forKey key: String) async throws {
        defaults.removeObject(forKey: key)
    }
}

/// In-memory session storage, useful for tests and previews.
public actor InMemoryVoicePracticeSessionStore: VoicePracticeSessionStore {
    private var storage: [String: VoicePracticeSession] = [:]

    public init() {}

    public func save(session: VoicePracticeSession, forKey key: String) async throws {
        storage[key] = session
    }

    public func loadSession(forKey key: String) async throws -> VoicePracticeSession? {
        storage[key]
    }

    public func clearSession(forKey key: String) async throws {
        storage.removeValue(forKey: key)
    }
}
