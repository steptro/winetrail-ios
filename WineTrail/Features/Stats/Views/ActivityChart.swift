import SwiftUI
import Charts

/// A bar chart showing the user's tasting activity per week.
///
/// Plots `ActivityPoint` data (week start date + count) as vertical bars,
/// giving the user a visual sense of their engagement over time.
struct ActivityChart: View {
    let timeline: [Components.Schemas.ActivityPoint]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private var chartData: [ActivityEntry] {
        timeline.compactMap { point in
            // weekStart comes as a String in "yyyy-MM-dd" format from the generated code
            guard let dateString = point.weekStart,
                  let date = Self.dateFormatter.date(from: dateString) else { return nil }
            return ActivityEntry(weekStart: date, count: Int(point.count ?? 0))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.smallSpacing) {
            Text("Weekly Activity")
                .font(Theme.headlineFont)
                .foregroundStyle(.wineText)

            if chartData.isEmpty {
                Text("No activity data available")
                    .font(Theme.captionFont)
                    .foregroundStyle(.wineSecondaryText)
            } else {
                Chart(chartData) { entry in
                    BarMark(
                        x: .value("Week", entry.weekStart, unit: .weekOfYear),
                        y: .value("Tastings", entry.count)
                    )
                    .foregroundStyle(.wineAccent.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: xAxisStride)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
            }
        }
        .padding(Theme.spacing)
        .background(.wineSecondaryBackground, in: .rect(cornerRadius: Theme.cornerRadius))
    }

    /// Determines a reasonable x-axis stride based on data point count.
    private var xAxisStride: Int {
        let count = chartData.count
        if count <= 8 { return 1 }
        if count <= 16 { return 2 }
        return 4
    }
}

// MARK: - Data Model

private struct ActivityEntry: Identifiable {
    let weekStart: Date
    let count: Int

    var id: Date { weekStart }
}

#Preview {
    ActivityChart(timeline: [])
    .padding()
}
