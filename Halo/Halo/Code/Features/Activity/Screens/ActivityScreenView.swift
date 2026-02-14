import SwiftUI
import SwiftData

struct ActivityScreenView: View {
    @Query(sort: \StoredActivitySample.timestamp, order: .reverse) private var storedActivitySamples: [StoredActivitySample]

    private var calendar: Calendar { Calendar.current }

    private var todayActivitySamples: [StoredActivitySample] {
        storedActivitySamples
            .filter { calendar.isDateInToday($0.timestamp) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var stepsData: [TimeSeriesPoint] {
        todayActivitySamples.map { TimeSeriesPoint(time: $0.timestamp, value: Double($0.steps)) }
    }

    private var distanceData: [TimeSeriesPoint] {
        todayActivitySamples.map { TimeSeriesPoint(time: $0.timestamp, value: $0.distanceKm) }
    }

    private var caloriesData: [TimeSeriesPoint] {
        todayActivitySamples.map { TimeSeriesPoint(time: $0.timestamp, value: Double($0.calories)) }
    }

    private var chartStepsData: [TimeSeriesPoint] {
        stepsData.isEmpty ? PreviewData.stepsPerHour : stepsData
    }

    private var chartDistanceData: [TimeSeriesPoint] {
        distanceData.isEmpty ? PreviewData.distancePerHour : distanceData
    }

    private var chartCaloriesData: [TimeSeriesPoint] {
        caloriesData.isEmpty ? PreviewData.caloriesPerHour : caloriesData
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ActivityStepsCumulativeChartView(
                        data: chartStepsData,
                        title: L10n.Activity.stepsTitle
                    )
                    ActivityDistanceCumulativeChartView(
                        data: chartDistanceData,
                        title: L10n.Activity.distanceTitle
                    )
                    ActivityCaloriesCumulativeChartView(
                        data: chartCaloriesData,
                        title: L10n.Activity.caloriesTitle
                    )
                } header: {
                    Label(L10n.Tab.activity, systemImage: "figure.walk")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.Tab.activity)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
