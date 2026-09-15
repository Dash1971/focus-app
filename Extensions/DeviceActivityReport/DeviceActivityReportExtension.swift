import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct LockInDeviceActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        DailyActivityReportScene()
    }
}

private struct DailyActivityConfiguration: Hashable {
    let unlocks: Int
    let unlockDuration: TimeInterval
    let screenTime: TimeInterval
}

private struct DailyActivityReportScene: DeviceActivityReportScene {
    let context = DeviceActivityReport.Context(AppConstants.dailyActivityReport)
    let content: (DailyActivityConfiguration) -> DailyActivityCard = { configuration in
        DailyActivityCard(configuration: configuration)
    }

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> DailyActivityConfiguration {
        var screenTime: TimeInterval = 0
        for await activity in data {
            for await segment in activity.activitySegments {
                screenTime += segment.totalActivityDuration
            }
        }

        let unlockActivity = (try? SharedStore.shared.load())?.unlockActivity() ?? (count: 0, duration: 0)
        return DailyActivityConfiguration(
            unlocks: unlockActivity.count,
            unlockDuration: unlockActivity.duration,
            screenTime: screenTime
        )
    }
}

private struct DailyActivityCard: View {
    let configuration: DailyActivityConfiguration

    var body: some View {
        HStack(spacing: 0) {
            stat("UNLOCKS", "\(configuration.unlocks)")
            stat("UNLOCK TIME", duration(configuration.unlockDuration))
            stat("SCREEN TIME", duration(configuration.screenTime))
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.055), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.14)))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds)) / 60
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 { return remainder > 0 ? "\(hours)h \(remainder)m" : "\(hours)h" }
        return "\(minutes)m"
    }
}
