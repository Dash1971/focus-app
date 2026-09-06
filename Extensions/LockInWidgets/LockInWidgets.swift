import WidgetKit
import SwiftUI

struct LockInEntry: TimelineEntry {
    let date: Date
    let configured: Bool
    let temporaryEnd: Date?
}

struct LockInProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockInEntry { .init(date: .now, configured: true, temporaryEnd: nil) }
    func getSnapshot(in context: Context, completion: @escaping (LockInEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LockInEntry>) -> Void) {
        let value = entry()
        var entries = [value]
        if let end = value.temporaryEnd, end > value.date {
            // Precompute the expired entry instead of depending on a refresh at
            // an arbitrary point in the past or a widget process waking on time.
            entries.append(.init(date: end, configured: value.configured, temporaryEnd: nil))
        }
        completion(Timeline(entries: entries, policy: .after((value.temporaryEnd ?? value.date).addingTimeInterval(15 * 60))))
    }
    private func entry() -> LockInEntry {
        let state = try? SharedStore.shared.load()
        return .init(date: .now, configured: state.map { !$0.selection.isEmpty } ?? false,
                     temporaryEnd: state?.grant.flatMap { $0.deadline.isActive() ? $0.deadline.endsAt : nil })
    }
}

struct LockInWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LockInEntry
    var body: some View {
        Group {
            if family == .accessoryCircular {
                Image(systemName: "lock.fill")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("LockIn", systemImage: "lock.fill").font(.headline)
                    if let end = entry.temporaryEnd, end > entry.date {
                        Text("Temporary access").font(.caption)
                        Text(timerInterval: entry.date...end, countsDown: true).monospacedDigit()
                    } else {
                        Text(entry.configured ? "Locked by default" : "Choose your distractions").font(.subheadline)
                    }
                    if family == .systemSmall || family == .systemMedium { Text("Open LockIn").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        .containerBackground(Color(white: 0.08), for: .widget)
        .widgetURL(URL(string: "lockin://home"))
    }
}

struct LockInWidget: Widget {
    let kind = "LockInWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockInProvider()) { LockInWidgetView(entry: $0) }
            .configurationDisplayName("LockIn")
            .description("Keep distractions locked and open LockIn for temporary access.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct LockInWidgetBundle: WidgetBundle {
    var body: some Widget { LockInWidget() }
}
