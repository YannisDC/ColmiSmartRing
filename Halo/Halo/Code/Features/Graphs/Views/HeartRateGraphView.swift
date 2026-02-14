//
//  HeartRateGraphView.swift
//  Halo
//
//  Created by Yannis De Cleene on 27/01/2025.
//

import SwiftUI
import Charts

struct HeartRateDataPoint: Identifiable {
    let id = UUID()
    let heartRate: Int
    let time: Date
}

struct HeartRateGraphView: View {
    let data: [HeartRateDataPoint]

    var body: some View {
        Chart {
            ForEach(data) { point in
                LineMark(
                    x: .value(L10n.HeartRateGraph.axisTime, point.time),
                    y: .value(L10n.HeartRateGraph.axisHeartRate, point.heartRate)
                )
                .interpolationMethod(.catmullRom) // Smooth the line
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) // Y-axis on the left
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .padding()
        .frame(height: 300) // Adjust graph size
    }
}

struct HeartRateGraphContainerView: View {
    @State private var data: [HeartRateDataPoint] = []

    var body: some View {
        VStack {
            if data.isEmpty {
                Text(L10n.HeartRateGraph.noDataAvailable)
                    .foregroundColor(.gray)
            } else {
                HeartRateGraphView(data: data)
            }
        }
    }
}

#Preview("Heart Rate (PreviewData)") {
    List {
        HeartRateGraphView(data: PreviewData.heartRatePoints)
    }
}
