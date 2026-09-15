import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct LockInDeviceActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene { DailyActivityReportScene() }
}

private struct DailyActivityConfiguration {
    // No returned segments is unavailable data, not measured zero usage.
    let screenTime: TimeInterval?
}

private struct DailyActivityReportScene: DeviceActivityReportScene {
    let context = DeviceActivityReport.Context(AppConstants.dailyActivityReport)
    let content: (DailyActivityConfiguration) -> DailyScreenTimeValue = { DailyScreenTimeValue(configuration: $0) }

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> DailyActivityConfiguration {
        var screenTime: TimeInterval = 0
        var hasSegments = false
        for await activity in data {
            for await segment in activity.activitySegments {
                hasSegments = true
                screenTime += segment.totalActivityDuration
            }
        }
        // The host supplies an unfiltered current-user iPhone report, including
        // unrestricted apps. No application/category/domain selection is applied.
        // Unlock counters stay in the host; this sandbox need not read its file.
        return DailyActivityConfiguration(screenTime: hasSegments ? screenTime : nil)
    }
}

private struct DailyScreenTimeValue: View {
    let configuration: DailyActivityConfiguration
    var body: some View {
        Text(configuration.screenTime.map(TimePolicy.activityDuration) ?? "—")
            .font(.title2.monospacedDigit())
            .foregroundStyle(.white)
            .lineLimit(1).minimumScaleFactor(0.65)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(white: 0.09))
            .accessibilityLabel("Total Screen Time")
            .accessibilityValue(configuration.screenTime.map(TimePolicy.activityDuration) ?? "Not available")
    }
}
