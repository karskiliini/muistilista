import WidgetKit
import SwiftUI
import SwiftData

struct CountEntry: TimelineEntry {
    let date: Date
    let remaining: Int
}

struct CountProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountEntry {
        CountEntry(date: .now, remaining: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (CountEntry) -> Void) {
        completion(CountEntry(date: .now, remaining: remainingCount()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountEntry>) -> Void) {
        let entry = CountEntry(date: .now, remaining: remainingCount())
        // Fallback refresh every 30 min; the app reloads timelines on changes.
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(1800))))
    }

    private func remainingCount() -> Int {
        do {
            let context = ModelContext(try SharedStore.container())
            let descriptor = FetchDescriptor<ShoppingItem>(predicate: #Predicate { !$0.isDone })
            return try context.fetchCount(descriptor)
        } catch {
            return 0
        }
    }
}

struct CountWidgetView: View {
    let entry: CountEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "cart.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.green)
            Spacer()
            Text("\(entry.remaining)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
            Text(entry.remaining == 1 ? "tuote ostettavana" : "tuotetta ostettavana")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color(UIColor.systemBackground) }
    }
}

@main
struct OstoslistaWidgetBundle: WidgetBundle {
    var body: some Widget {
        OstoslistaCountWidget()
    }
}

struct OstoslistaCountWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OstoslistaCount", provider: CountProvider()) { entry in
            CountWidgetView(entry: entry)
        }
        .configurationDisplayName("Ostoslista")
        .description("Näyttää montako tuotetta on ostettavana.")
        .supportedFamilies([.systemSmall])
    }
}
