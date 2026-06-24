import WidgetKit
import SwiftUI

struct VAYAWaterWidget: Widget {
    let kind = "VAYAWaterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VAYAWidgetProvider()) { entry in
            VAYAWaterWidgetView(entry: entry)
                .widgetURL(WidgetSharedConstants.homeTabURL)
                .vayaWidgetBackground()
        }
        .configurationDisplayName("Water")
        .description("Monitor today's hydration.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct VAYAWaterWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: VAYAWidgetEntry

    private var progress: Double {
        guard entry.snapshot.waterGoalML > 0 else { return 0 }
        return min(Double(entry.snapshot.waterTodayML) / Double(entry.snapshot.waterGoalML), 1)
    }

    private var percent: Int {
        Int((progress * 100).rounded())
    }

    var body: some View {
        waterContent
    }

    @ViewBuilder
    private var waterContent: some View {
        VStack(alignment: .leading, spacing: widgetFamily == .systemSmall ? 8 : 10) {
            VAYAWidgetCardHeader(
                title: "Water",
                systemImage: "drop.fill",
                value: "\(percent)%",
                subtitle: "of daily goal"
            )

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(entry.snapshot.waterTodayML.formatted())
                    .font(.system(size: widgetFamily == .systemSmall ? 22 : 26, weight: .bold, design: .rounded))
                    .foregroundStyle(VAYAWidgetPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("ml")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(VAYAWidgetPalette.textSecondary)
            }

            Text("of \(entry.snapshot.waterGoalML.formatted()) ml goal")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(VAYAWidgetPalette.textSecondary)

            Capsule()
                .fill(VAYAWidgetPalette.trackBackground)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(VAYAWidgetPalette.waterBlue)
                        .scaleEffect(x: progress, anchor: .leading)
                }
                .frame(height: 8)

            if widgetFamily != .systemSmall {
                HStack(spacing: 4) {
                    ForEach(0..<entry.snapshot.waterGlassCount, id: \.self) { index in
                        Image(systemName: index < entry.snapshot.filledWaterGlasses ? "drop.fill" : "drop")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(
                                index < entry.snapshot.filledWaterGlasses
                                    ? VAYAWidgetPalette.waterBlue
                                    : VAYAWidgetPalette.textTertiary
                            )
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(widgetFamily.vayaContentPadding)
    }
}

#Preview(as: .systemSmall) {
    VAYAWaterWidget()
} timeline: {
    VAYAWidgetEntry(date: .now, snapshot: .preview)
}
