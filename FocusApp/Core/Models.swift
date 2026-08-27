import Foundation
import FamilyControls
import DeviceActivity

enum AppConstants {
    static let appGroup = "group.com.dash1971.focusapp"
    static let focusActivity = "activeFocusSession"
    static let schedulePrefix = "schedule."
    static let managedStorePrefix = "focus."
}

enum ChallengeKind: String, Codable, CaseIterable, Identifiable {
    case none, pushUps, squats, sitUps, plank, math, reading, cleaning, custom

    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "No challenge required"
        case .pushUps: "Push-ups"
        case .squats: "Squats"
        case .sitUps: "Sit-ups"
        case .plank: "Plank"
        case .math: "Math equation"
        case .reading: "Read pages"
        case .cleaning: "Clean or organize"
        case .custom: "Custom challenge"
        }
    }
}

struct Challenge: Codable, Equatable {
    var kind: ChallengeKind = .none
    var amount: Int = 10
    var customText: String = ""

    var instruction: String {
        switch kind {
        case .none: "No challenge required"
        case .pushUps: "Complete \(amount) push-ups"
        case .squats: "Complete \(amount) squats"
        case .sitUps: "Complete \(amount) sit-ups"
        case .plank: "Hold a plank for \(amount) seconds"
        case .math: "Solve a short math challenge"
        case .reading: "Read \(amount) pages"
        case .cleaning: "Clean or organize for \(amount) minutes"
        case .custom: customText.isEmpty ? "Complete your custom challenge" : customText
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
}

struct ActiveFocusSession: Codable, Equatable {
    let id: UUID
    let startedAt: Date
    let endsAt: Date
    let plannedMinutes: Int
    let challenge: Challenge
}

struct BlockSchedule: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = "Study"
    var startMinutes: Int = 19 * 60 + 30
    var endMinutes: Int = 20 * 60 + 30
    var weekdays: Set<Int> = Set(1...7)
    var enabled: Bool = true
    var challenge: Challenge = .init()

    var startDate: Date {
        Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(startMinutes * 60))
    }
    var endDate: Date {
        Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(endMinutes * 60))
    }
}

struct IntervalConfiguration: Codable, Equatable {
    var workSeconds = 40
    var restSeconds = 15
    var rounds = 5
    var autoAdvance = true
}

struct SharedSnapshot: Codable {
    var selection = FamilyActivitySelection()
    var activeSession: ActiveFocusSession?
    var schedules: [BlockSchedule] = []
    var records: [FocusSessionRecord] = []
    var challengesCompleted = 0
    var emergencyUnlocks = 0
}

extension DeviceActivityName {
    static let focusSession = Self(AppConstants.focusActivity)
    static func schedule(_ id: UUID) -> Self { Self(AppConstants.schedulePrefix + id.uuidString) }
}
