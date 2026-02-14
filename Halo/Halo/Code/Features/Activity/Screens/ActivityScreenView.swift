import SwiftUI

struct ActivityScreenView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ActivityStepsCumulativeComparisonChartView(
                        comparisonData: PreviewData.stepsPerHourWeeklyAverage,
                        data: PreviewData.stepsPerHour,
                        title: L10n.Activity.stepsTitle
                    )
                    ActivityDistanceCumulativeComparisonChartView(
                        comparisonData: PreviewData.distancePerHourWeeklyAverage,
                        data: PreviewData.distancePerHour,
                        title: L10n.Activity.distanceTitle
                    )
                    ActivityCaloriesCumulativeComparisonChartView(
                        comparisonData: PreviewData.caloriesPerHourWeeklyAverage,
                        data: PreviewData.caloriesPerHour,
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
