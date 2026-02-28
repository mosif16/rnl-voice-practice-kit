import Foundation

/// User preferences for voice practice sessions.
public struct VoicePracticeSettings: Codable, Sendable, Hashable {
    public var speechRate: SpeechRate
    public var voiceIdentifier: String?
    public var silenceTimeout: TimeInterval
    public var autoAdvance: Bool
    public var showTranscript: Bool
    public var handsFreeModeEnabled: Bool
    public var followUpEnabled: Bool
    public var showCaptions: Bool
    public var visualModeEnabled: Bool

    public init(
        speechRate: SpeechRate = .normal,
        voiceIdentifier: String? = nil,
        silenceTimeout: TimeInterval = 2.0,
        autoAdvance: Bool = true,
        showTranscript: Bool = true,
        handsFreeModeEnabled: Bool = false,
        followUpEnabled: Bool = true,
        showCaptions: Bool = false,
        visualModeEnabled: Bool = false
    ) {
        self.speechRate = speechRate
        self.voiceIdentifier = voiceIdentifier
        self.silenceTimeout = silenceTimeout
        self.autoAdvance = autoAdvance
        self.showTranscript = showTranscript
        self.handsFreeModeEnabled = handsFreeModeEnabled
        self.followUpEnabled = followUpEnabled
        self.showCaptions = showCaptions
        self.visualModeEnabled = visualModeEnabled
    }

    public static let `default` = VoicePracticeSettings()

    public static let defaultStorageKey = "VoicePracticeSettings"

    public static func load(
        from defaults: UserDefaults = .standard,
        key: String = defaultStorageKey
    ) -> VoicePracticeSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(VoicePracticeSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    public func save(
        to defaults: UserDefaults = .standard,
        key: String = VoicePracticeSettings.defaultStorageKey
    ) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Speech rate options for TTS.
public enum SpeechRate: String, Codable, Sendable, CaseIterable, Hashable {
    case slow
    case normal
    case fast

    /// Service-facing normalized speech rate value.
    public var synthesizerRate: Float {
        switch self {
        case .slow:
            return 0.4
        case .normal:
            return 0.5
        case .fast:
            return 0.6
        }
    }

    public var displayName: String {
        switch self {
        case .slow:
            return "Slow"
        case .normal:
            return "Normal"
        case .fast:
            return "Fast"
        }
    }
}
