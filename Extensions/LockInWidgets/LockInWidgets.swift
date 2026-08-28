import WidgetKit
import SwiftUI

struct LockInEntry: TimelineEntry {
    let date: Date
    let sessionEnd: Date?
    let focusMinutesToday: Int
    let sessionsToday: Int
    let challengesCompleted: Int
    let selectedItems: Int
}

struct LockInProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockInEntry {
        .init(date: .now, sessionEnd: Date().addingTimeInterval(25 * 60), focusMinutesToday: 45, sessionsToday: 2, challengesCompleted: 1, selectedItems: 4)
    }

    func getSnapshot(in context: Context, completion: @escaping (LockInEntry) -> Void) { completion(entry()) }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockInEntry>) -> Void) {
        let value = entry()
        let refresh = value.sessionEnd.map { min($0, Date().addingTimeInterval(60)) } ?? Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [value], policy: .after(refresh)))
    }

    private func entry() -> LockInEntry {
        let snapshot = SharedStore.shared.load()
        let completedToday = snapshot.records.filter { Calendar.current.isDateInToday($0.endedAt) && $0.completed }
        return .init(
            date: .now,
            sessionEnd: snapshot.activeSession?.endsAt,
            focusMinutesToday: completedToday.reduce(0) { $0 + $1.plannedMinutes },
            sessionsToday: completedToday.count,
            challengesCompleted: snapshot.challengesCompleted,
            selectedItems: snapshot.selection.applicationTokens.count + snapshot.selection.categoryTokens.count + snapshot.selection.webDomainTokens.count
        )
    }
}

struct LockInWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LockInEntry

    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: entry.sessionEnd == nil ? "lock.open.fill" : "lock.fill")
            }
            .widgetURL(URL(string: "lockin://focus"))
        } else if family == .accessoryRectangular {
            VStack(alignment: .leading) {
                Text("LOCKIN").font(.caption.bold())
                if let end = entry.sessionEnd, end > entry.date {
                    Text(timerInterval: entry.date...end, countsDown: true).monospacedDigit()
                    Text("Focus active").font(.caption2)
                } else {
                    Text("\(entry.focusMinutesToday)m today")
                    Text("Tap to start focus").font(.caption2)
                }
            }.widgetURL(URL(string: "lockin://focus"))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text("🔒"); Text("LockIn").font(.headline); Spacer() }
                if let end = entry.sessionEnd, end > entry.date {
                    Text("FOCUS ACTIVE").font(.caption.bold()).foregroundStyle(.indigo)
                    Text(timerInterval: entry.date...end, countsDown: true).font(.title2.bold()).monospacedDigit()
                } else {
                    HStack {
                        stat("\(entry.focusMinutesToday)m", "Focus")
                        stat("\(entry.sessionsToday)", "Sessions")
                        stat("\(entry.challengesCompleted)", "Challenges")
                    }
                }
                HStack {
                    Link("Start Focus", destination: URL(string: "lockin://focus")!)
                    Spacer()
                    Link("Timer", destination: URL(string: "lockin://timer")!)
                }.font(.caption.bold())
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading) { Text(value).font(.headline); Text(label).font(.caption2).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LockInWidget: Widget {
    let kind = "LockInWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockInProvider()) { LockInWidgetView(entry: $0) }
            .configurationDisplayName("LockIn")
            .description("See focus progress and quickly open LockIn tools.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct LockInWidgetBundle: WidgetBundle {
    var body: some Widget { LockInWidget() }
}
