import Foundation
import FamilyControls
import DeviceActivity

enum AppConstants {
    static let appGroup = "group.com.dash1971.focusapp"
    static let focusActivity = "activeFocusSession"
    static let schedulePrefix = "schedule."
    static let managedStorePrefix = "focus." // Retained for compatibility with installed builds.
}

enum ChallengeKind: String, Codable, CaseIterable, Identifiable {
    case none, pushUps, squats, sitUps, plank, lunges, bicepCurls, shoulderPresses
    case math, puzzle, question, reading, cleaning, custom

    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "No challenge required"
        case .pushUps: "Push-ups"
        case .squats: "Squats"
        case .sitUps: "Sit-ups"
        case .plank: "Plank"
        case .lunges: "Lunges"
        case .bicepCurls: "Bicep curls"
        case .shoulderPresses: "Shoulder presses"
        case .math: "Math equation"
        case .puzzle: "Small puzzle"
        case .question: "Answer a question"
        case .reading: "Read pages"
        case .cleaning: "Clean or organize"
        case .custom: "Custom challenge"
        }
    }
}

struct Challenge: Codable, Equatable {
    var kind: ChallengeKind = .none
    var amount: Int = 10
    var weightKilograms: Double = 5
    var customText: String = ""
    var expectedAnswer: String = ""

    private enum CodingKeys: String, CodingKey { case kind, amount, weightKilograms, customText, expectedAnswer }
    init(kind: ChallengeKind = .none, amount: Int = 10, weightKilograms: Double = 5, customText: String = "", expectedAnswer: String = "") {
        self.kind = kind; self.amount = amount; self.weightKilograms = weightKilograms; self.customText = customText; self.expectedAnswer = expectedAnswer
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        kind = try values.decodeIfPresent(ChallengeKind.self, forKey: .kind) ?? .none
        amount = try values.decodeIfPresent(Int.self, forKey: .amount) ?? 10
        weightKilograms = try values.decodeIfPresent(Double.self, forKey: .weightKilograms) ?? 5
        customText = try values.decodeIfPresent(String.self, forKey: .customText) ?? ""
        expectedAnswer = try values.decodeIfPresent(String.self, forKey: .expectedAnswer) ?? ""
    }

    var instruction: String {
        switch kind {
        case .none: "No challenge required"
        case .pushUps: "Complete \(amount) push-ups"
        case .squats: "Complete \(amount) squats"
        case .sitUps: "Complete \(amount) sit-ups"
        case .plank: "Hold a plank for \(amount) seconds"
        case .lunges: "Complete \(amount) lunges"
        case .bicepCurls: "Complete \(amount) bicep curls at \(weightKilograms.formatted()) kg"
        case .shoulderPresses: "Complete \(amount) shoulder presses at \(weightKilograms.formatted()) kg"
        case .math: "Solve a short math challenge"
        case .puzzle: "Complete a short puzzle"
        case .question: customText.isEmpty ? "Answer the question" : customText
        case .reading: "Read \(amount) pages"
        case .cleaning: "Clean or organize for \(amount) minutes"
        case .custom: customText.isEmpty ? "Complete your custom challenge" : customText
        }
    }

    var validationMessage: String? {
        switch kind {
        case .question where customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
            "Enter the question users must answer."
        case .question where expectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
            "Enter the correct answer for this challenge."
        case .custom where customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
            "Describe the custom challenge."
        default:
            nil
        }
    }
}

struct FocusSessionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let plannedMinutes: Int
    let completed: Bool
    let emergencyUnlock: Bool

    var displayedMinutes: Int {
        completed ? plannedMinutes : max(0, Int(endedAt.timeIntervalSince(startedAt) / 60))
    }
}

struct ActiveFocusSession: Codable, Equatable {
    let id: UUID
    let startedAt: Date
    let endsAt: Date
    let plannedMinutes: Int
    let challenge: Challenge
    let selection: FamilyActivitySelection

    private enum CodingKeys: String, CodingKey { case id, startedAt, endsAt, plannedMinutes, challenge, selection }
    init(id: UUID, startedAt: Date, endsAt: Date, plannedMinutes: Int, challenge: Challenge, selection: FamilyActivitySelection = .init()) {
        self.id = id; self.startedAt = startedAt; self.endsAt = endsAt; self.plannedMinutes = plannedMinutes; self.challenge = challenge; self.selection = selection
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        endsAt = try values.decode(Date.self, forKey: .endsAt)
        plannedMinutes = try values.decode(Int.self, forKey: .plannedMinutes)
        challenge = try values.decodeIfPresent(Challenge.self, forKey: .challenge) ?? .init()
        selection = try values.decodeIfPresent(FamilyActivitySelection.self, forKey: .selection) ?? .init()
    }
}

struct BlockSchedule: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = "Study"
    var startMinutes: Int = 19 * 60 + 30
    var endMinutes: Int = 20 * 60 + 30
    var weekdays: Set<Int> = Set(1...7)
    var enabled: Bool = true
    var challenge: Challenge = .init()
    var selection: FamilyActivitySelection = .init()

    private enum CodingKeys: String, CodingKey { case id, name, startMinutes, endMinutes, weekdays, enabled, challenge, selection }
    init(id: UUID = UUID(), name: String = "Study", startMinutes: Int = 19 * 60 + 30, endMinutes: Int = 20 * 60 + 30, weekdays: Set<Int> = Set(1...7), enabled: Bool = true, challenge: Challenge = .init(), selection: FamilyActivitySelection = .init()) {
        self.id = id; self.name = name; self.startMinutes = startMinutes; self.endMinutes = endMinutes; self.weekdays = weekdays; self.enabled = enabled; self.challenge = challenge; self.selection = selection
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? "Study"
        startMinutes = try values.decodeIfPresent(Int.self, forKey: .startMinutes) ?? 19 * 60 + 30
        endMinutes = try values.decodeIfPresent(Int.self, forKey: .endMinutes) ?? 20 * 60 + 30
        weekdays = try values.decodeIfPresent(Set<Int>.self, forKey: .weekdays) ?? Set(1...7)
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        challenge = try values.decodeIfPresent(Challenge.self, forKey: .challenge) ?? .init()
        selection = try values.decodeIfPresent(FamilyActivitySelection.self, forKey: .selection) ?? .init()
    }

    var startDate: Date {
        Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(startMinutes * 60))
    }
    var endDate: Date {
        ScheduleTiming.activeEndDate(startMinutes: startMinutes, endMinutes: endMinutes)
    }
}

struct IntervalConfiguration: Codable, Equatable {
    var workSeconds = 40
    var restSeconds = 15
    var rounds = 5
    var autoAdvance = true
    var sound: TimerSound = .bell
}

enum TimerSound: String, Codable, CaseIterable, Identifiable {
    case bell, chime, alert, silent
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var systemSoundID: UInt32 { switch self { case .bell: 1005; case .chime: 1054; case .alert: 1007; case .silent: 0 } }
}

struct SharedSnapshot: Codable {
    var selection = FamilyActivitySelection()
    var activeSession: ActiveFocusSession?
    var schedules: [BlockSchedule] = []
    var records: [FocusSessionRecord] = []
    var challengesCompleted = 0
    var emergencyUnlocks = 0
    var customChallenges: [Challenge] = []

    private enum CodingKeys: String, CodingKey { case selection, activeSession, schedules, records, challengesCompleted, emergencyUnlocks, customChallenges }
    init(selection: FamilyActivitySelection = .init(), activeSession: ActiveFocusSession? = nil, schedules: [BlockSchedule] = [], records: [FocusSessionRecord] = [], challengesCompleted: Int = 0, emergencyUnlocks: Int = 0, customChallenges: [Challenge] = []) {
        self.selection = selection; self.activeSession = activeSession; self.schedules = schedules; self.records = records; self.challengesCompleted = challengesCompleted; self.emergencyUnlocks = emergencyUnlocks; self.customChallenges = customChallenges
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        selection = try values.decodeIfPresent(FamilyActivitySelection.self, forKey: .selection) ?? .init()
        activeSession = try values.decodeIfPresent(ActiveFocusSession.self, forKey: .activeSession)
        schedules = try values.decodeIfPresent([BlockSchedule].self, forKey: .schedules) ?? []
        records = try values.decodeIfPresent([FocusSessionRecord].self, forKey: .records) ?? []
        challengesCompleted = try values.decodeIfPresent(Int.self, forKey: .challengesCompleted) ?? 0
        emergencyUnlocks = try values.decodeIfPresent(Int.self, forKey: .emergencyUnlocks) ?? 0
        customChallenges = try values.decodeIfPresent([Challenge].self, forKey: .customChallenges) ?? []
    }
}

extension DeviceActivityName {
    static let focusSession = Self(AppConstants.focusActivity)
    static func schedule(_ id: UUID) -> Self { Self(AppConstants.schedulePrefix + id.uuidString) }
}
