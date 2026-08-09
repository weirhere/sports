import SwiftUI
import WidgetKit

struct NextGameWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppGroup.widgetKind, provider: NextGameProvider()) { entry in
            NextGameWidgetView(entry: entry)
                .containerBackground(Color.bgPrimary, for: .widget)
        }
        .configurationDisplayName("Your Teams")
        .description("Live score or next kickoff for the teams you follow.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

#Preview("Small", as: .systemSmall) {
    NextGameWidget()
} timeline: {
    NextGameEntry.sample
    NextGameEntry(date: .now, state: .noFollows)
}

#Preview("Medium", as: .systemMedium) {
    NextGameWidget()
} timeline: {
    NextGameEntry.sample
}

#Preview("Lock screen", as: .accessoryRectangular) {
    NextGameWidget()
} timeline: {
    NextGameEntry.sample
}
