//
//  MeasurementChartsView.swift
//  Halo
//
//  SwiftUI chart views for all measurement types (Activity, HRV, Blood Oxygen, Stress)
//  using SwiftCharts. Each view has a Preview using PreviewData.
//

import SwiftUI
import Charts

// MARK: - Activity (Steps, Distance, Calories)

struct ActivityStepsChartView: View {
    let data: [TimeSeriesPoint]
    var title: String = "Steps"
    var color: Color = .cyan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Chart(data) { point in
                BarMark(
                    x: .value("Time", point.time),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color.gradient)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 180)
        }
        .padding(.vertical, 4)
    }
}

struct ActivityDistanceChartView: View {
    let data: [TimeSeriesPoint]
    var title: String = "Distance"
    var color: Color = .green

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Chart(data) { point in
                BarMark(
                    x: .value("Time", point.time),
                    y: .value("Km", point.value)
                )
                .foregroundStyle(color.gradient)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 180)
        }
        .padding(.vertical, 4)
    }
}

struct ActivityCaloriesChartView: View {
    let data: [TimeSeriesPoint]
    var title: String = "Calories"
    var color: Color = .red

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Chart(data) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Kcal", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color.gradient)
                PointMark(
                    x: .value("Time", point.time),
                    y: .value("Kcal", point.value)
                )
                .foregroundStyle(color)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 180)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Activity cumulative (line charts)

/// Builds cumulative time series from incremental data (sorted by time, running sum).
func cumulativeSeries(from data: [TimeSeriesPoint]) -> [TimeSeriesPoint] {
    let sorted = data.sorted { $0.time < $1.time }
    var running: Double = 0
    return sorted.map { point in
        running += point.value
        return TimeSeriesPoint(time: point.time, value: running)
    }
}

struct ActivityStepsCumulativeChartView: View {
    let data: [TimeSeriesPoint]
    var title: String = "Steps (cumulative)"
    var color: Color = .cyan

    private var cumulative: [TimeSeriesPoint] { cumulativeSeries(from: data) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Chart(cumulative) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Steps", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color.gradient)
                AreaMark(
                    x: .value("Time", point.time),
                    y: .value("Steps", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color.gradient.opacity(0.3))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 180)
        }
        .padding(.vertical, 4)
    }
}

struct ActivityDistanceCumulativeChartView: View {
    let data: [TimeSeriesPoint]
    var title: String = "Distance (cumulative)"
    var color: Color = .green

    private var cumulative: [TimeSeriesPoint] { cumulativeSeries(from: data) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Chart(cumulative) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Km", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color.gradient)
                AreaMark(
                    x: .value("Time", point.time),
                    y: .value("Km", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color.gradient.opacity(0.3))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 180)
        }
        .padding(.vertical, 4)
    }
}

struct ActivityCaloriesCumulativeChartView: View {
    let data: [TimeSeriesPoint]
    var title: String = "Calories (cumulative)"
    var color: Color = .red

    private var cumulative: [TimeSeriesPoint] { cumulativeSeries(from: data) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Chart(cumulative) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Kcal", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color.gradient)
                AreaMark(
                    x: .value("Time", point.time),
                    y: .value("Kcal", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color.gradient.opacity(0.3))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 180)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Activity cumulative with comparison (no fill: gray weekly avg / yesterday, then today in color)

/// Point with a series label so Chart can color by series via chartForegroundStyleScale.
private struct SeriesTimeSeriesPoint: Identifiable {
    let id = UUID()
    let time: Date
    let value: Double
    let series: String
}

struct ActivityStepsCumulativeComparisonChartView: View {
    let comparisonData: [TimeSeriesPoint]
    let data: [TimeSeriesPoint]
    var title: String = "Steps (cumulative)"
    var comparisonLabel: String = "Weekly average"
    var color: Color = .cyan

    private var comparisonCumulative: [TimeSeriesPoint] { cumulativeSeries(from: comparisonData) }
    private var cumulative: [TimeSeriesPoint] { cumulativeSeries(from: data) }

    private var chartData: [SeriesTimeSeriesPoint] {
        comparisonCumulative.map { SeriesTimeSeriesPoint(time: $0.time, value: $0.value, series: "comparison") }
        + cumulative.map { SeriesTimeSeriesPoint(time: $0.time, value: $0.value, series: "today") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Chart(chartData) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Steps", point.value),
                    series: .value("Series", point.series)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Series", point.series))
                .lineStyle(StrokeStyle(lineWidth: point.series == "today" ? 2.5 : 1.5))
            }
            .chartForegroundStyleScale([
                "comparison": Color.gray,
                "today": color
            ])
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 180)
        }
        .padding(.vertical, 4)
    }
}

struct ActivityDistanceCumulativeComparisonChartView: View {
    let comparisonData: [TimeSeriesPoint]
    let data: [TimeSeriesPoint]
    var title: String = "Distance (cumulative)"
    var comparisonLabel: String = "Weekly average"
    var color: Color = .green

    private var comparisonCumulative: [TimeSeriesPoint] { cumulativeSeries(from: comparisonData) }
    private var cumulative: [TimeSeriesPoint] { cumulativeSeries(from: data) }

    private var chartData: [SeriesTimeSeriesPoint] {
        comparisonCumulative.map { SeriesTimeSeriesPoint(time: $0.time, value: $0.value, series: "comparison") }
        + cumulative.map { SeriesTimeSeriesPoint(time: $0.time, value: $0.value, series: "today") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Chart(chartData) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Km", point.value),
                    series: .value("Series", point.series)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Series", point.series))
                .lineStyle(StrokeStyle(lineWidth: point.series == "today" ? 2.5 : 1.5))
            }
            .chartForegroundStyleScale([
                "comparison": Color.gray,
                "today": color
            ])
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 180)
        }
        .padding(.vertical, 4)
    }
}

struct ActivityCaloriesCumulativeComparisonChartView: View {
    let comparisonData: [TimeSeriesPoint]
    let data: [TimeSeriesPoint]
    var title: String = "Calories (cumulative)"
    var comparisonLabel: String = "Weekly average"
    var color: Color = .red

    private var comparisonCumulative: [TimeSeriesPoint] { cumulativeSeries(from: comparisonData) }
    private var cumulative: [TimeSeriesPoint] { cumulativeSeries(from: data) }

    private var chartData: [SeriesTimeSeriesPoint] {
        comparisonCumulative.map { SeriesTimeSeriesPoint(time: $0.time, value: $0.value, series: "comparison") }
        + cumulative.map { SeriesTimeSeriesPoint(time: $0.time, value: $0.value, series: "today") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Chart(chartData) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Kcal", point.value),
                    series: .value("Series", point.series)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(by: .value("Series", point.series))
                .lineStyle(StrokeStyle(lineWidth: point.series == "today" ? 2.5 : 1.5))
            }
            .chartForegroundStyleScale([
                "comparison": Color.gray,
                "today": color
            ])
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 180)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - HRV (ms, line chart 0–178)

struct HRVChartView: View {
    let data: [TimeSeriesPoint]
    var title: String = "HRV"
    var unit: String = "ms"
    var yRange: ClosedRange<Double> = 0...178

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Chart(data) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value(unit, point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.orange.gradient)
            }
            .chartYScale(domain: yRange)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 200)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Blood Oxygen (%, bar 80–100)

struct BloodOxygenChartView: View {
    let data: [TimeSeriesPoint]
    var title: String = "Blood Oxygen"
    var unit: String = "%"
    var yRange: ClosedRange<Double> = 0...100

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Chart(data) { point in
                BarMark(
                    x: .value("Time", point.time),
                    y: .value(unit, point.value),
                    width: .fixed(6)
                )
                .foregroundStyle(Color.blue.gradient)
            }
            .chartYScale(domain: yRange)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 200)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Stress (0–100, bar or line)

struct StressChartView: View {
    let data: [TimeSeriesPoint]
    var title: String = "Stress"
    var yRange: ClosedRange<Double> = 0...100

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Chart(data) { point in
                BarMark(
                    x: .value("Time", point.time),
                    y: .value("Stress", point.value),
                    width: .fixed(6)
                )
                .foregroundStyle(Color.mint.gradient)
            }
            .chartYScale(domain: yRange)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 200)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview("Activity – Steps") {
    List {
        ActivityStepsChartView(data: PreviewData.stepsPerHour)
    }
}

#Preview("Activity – Distance") {
    List {
        ActivityDistanceChartView(data: PreviewData.distancePerHour)
    }
}

#Preview("Activity – Calories") {
    List {
        ActivityCaloriesChartView(data: PreviewData.caloriesPerHour)
    }
}

#Preview("HRV") {
    List {
        HRVChartView(data: PreviewData.hrvPoints)
    }
}

#Preview("Blood Oxygen") {
    List {
        BloodOxygenChartView(data: PreviewData.bloodOxygenPoints)
    }
}

#Preview("Stress") {
    List {
        StressChartView(data: PreviewData.stressPoints)
    }
}

#Preview("All activity charts") {
    List {
        ActivityStepsChartView(data: PreviewData.stepsPerHour)
        ActivityDistanceChartView(data: PreviewData.distancePerHour)
        ActivityCaloriesChartView(data: PreviewData.caloriesPerHour)
    }
}

#Preview("All activity cumulative") {
    List {
        ActivityStepsCumulativeChartView(data: PreviewData.stepsPerHour)
        ActivityDistanceCumulativeChartView(data: PreviewData.distancePerHour)
        ActivityCaloriesCumulativeChartView(data: PreviewData.caloriesPerHour)
    }
}

#Preview("All activity cumulative vs weekly avg") {
    List {
        ActivityStepsCumulativeComparisonChartView(
            comparisonData: PreviewData.stepsPerHourWeeklyAverage,
            data: PreviewData.stepsPerHour
        )
        ActivityDistanceCumulativeComparisonChartView(
            comparisonData: PreviewData.distancePerHourWeeklyAverage,
            data: PreviewData.distancePerHour
        )
        ActivityCaloriesCumulativeComparisonChartView(
            comparisonData: PreviewData.caloriesPerHourWeeklyAverage,
            data: PreviewData.caloriesPerHour
        )
    }
}

#Preview("All metric charts") {
    List {
        HRVChartView(data: PreviewData.hrvPoints)
        BloodOxygenChartView(data: PreviewData.bloodOxygenPoints)
        StressChartView(data: PreviewData.stressPoints)
    }
}
