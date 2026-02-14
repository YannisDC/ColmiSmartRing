//
//  SleepStageGraphView.swift
//  Halo
//
//  Sleep stage timeline and duration summary matching the reference sleep app UI.
//

import SwiftUI
import Charts

// MARK: - Stage colors and labels (reference: Wake=orange, REM=grey, Light=light purple, Deep=deep purple)

extension SleepType {
    var stageLabel: String {
        switch self {
        case .noData: return L10n.SleepStageLabel.noData
        case .error: return L10n.SleepStageLabel.error
        case .light: return L10n.SleepStageLabel.lightSleep
        case .deep: return L10n.SleepStageLabel.deepSleep
        case .core: return L10n.SleepStageLabel.rem
        case .awake: return L10n.SleepStageLabel.wakeUp
        }
    }

    var stageColor: Color {
        switch self {
        case .noData, .error: return Color.gray.opacity(0.5)
        case .awake: return Color.orange
        case .core: return Color.gray
        case .light: return Color.purple.opacity(0.6)
        case .deep: return Color.purple
        }
    }

    /// Order for stacking (deep bottom, then light, REM, awake top) – not used for single-band timeline.
    var displayOrder: Int {
        switch self {
        case .deep: return 0
        case .light: return 1
        case .core: return 2
        case .awake: return 3
        case .noData, .error: return 4
        }
    }
}

// MARK: - Segment for Charts (Identifiable)

private struct SleepSegment: Identifiable {
    let id = UUID()
    let start: Int
    let end: Int
    let type: SleepType
}

// MARK: - Sleep stage graph

struct SleepStageGraphView: View {
    let day: SleepDay
    var showsLegend: Bool = true
    var showsTimeline: Bool = true
    /// Optional: total duration override (defaults to day.totalDurationMinutes).
    var totalDuration: Int { day.totalDurationMinutes }

    private var segments: [SleepSegment] {
        day.segments.map { SleepSegment(start: $0.start, end: $0.end, type: $0.type) }
    }

    private func minuteToLabel(_ minuteFromStart: Int) -> String {
        let total = Int(day.sleepStart) + minuteFromStart
        let m = total % (24 * 60)
        let h = m / 60
        let min = m % 60
        return String(format: "%d:%02d", h, min)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            summaryHeader
            if showsLegend {
                legend
            }
            if showsTimeline {
                timelineChart
            }
            durationBars
        }
        .padding(.vertical, 8)
    }

    private var summaryHeader: some View {
        let startStr = minuteToLabel(0)
        let endStr = minuteToLabel(totalDuration)
        let hours = totalDuration / 60
        let mins = totalDuration % 60
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.SleepStage.totalDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(L10n.SleepStage.durationHM(hours: hours, mins: mins))
                    .font(.headline)
                Text(L10n.SleepStage.range(start: startStr, end: endStr))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach([SleepType.awake, .core, .light, .deep], id: \.rawValue) { type in
                HStack(spacing: 4) {
                    Circle()
                        .fill(type.stageColor)
                        .frame(width: 8, height: 8)
                    Text(type.stageLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var timelineChart: some View {
        let total = max(totalDuration, 1)
        return Chart(segments) { seg in
            RectangleMark(
                xStart: .value(L10n.SleepStage.axisStart, seg.start),
                xEnd: .value(L10n.SleepStage.axisEnd, seg.end),
                y: .value(L10n.SleepStage.axisStage, 0),
                height: .fixed(24)
            )
            .foregroundStyle(seg.type.stageColor)
        }
        .chartXScale(domain: 0...total)
        .chartXAxis {
            AxisMarks(values: .stride(by: 60)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let m = value.as(Int.self) {
                        Text(minuteToLabel(m))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 44)
        .padding(.horizontal, 4)
    }

    private var durationBars: some View {
        let stageMinutes = day.minutesPerStage()
        let total = totalDuration
        let displayTypes: [(SleepType, String)] = [
            (.awake, L10n.SleepStage.awakeTime),
            (.core, L10n.SleepStage.remDuration),
            (.light, L10n.SleepStage.lightSleepDuration),
            (.deep, L10n.SleepStage.deepSleepDuration)
        ]
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(displayTypes, id: \.0.rawValue) { type, label in
                let mins = stageMinutes[type] ?? 0
                let pct = total > 0 ? Double(mins) / Double(total) : 0
                let durationStr = mins >= 60
                    ? L10n.SleepStage.durationHM(hours: mins / 60, mins: mins % 60)
                    : L10n.SleepStage.durationM(mins: mins)
                HStack(spacing: 8) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(L10n.SleepStage.durationPct(durationStr, Int(pct * 100)))
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.25))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(type.stageColor)
                            .frame(width: max(0, geo.size.width * CGFloat(pct)))
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(.horizontal, 4)
    }
}

#Preview("Sleep stages (PreviewData)") {
    List {
        SleepStageGraphView(day: PreviewData.sleepDay)
    }
}

#Preview("Sleep stages (custom)") {
    let day = SleepDay(
        daysAgo: 0,
        curDayBytes: 20,
        sleepStart: 23 * 60,
        sleepEnd: 6 * 60 + 27,
        periods: [
            SleepPeriod(type: .light, minutes: 60),
            SleepPeriod(type: .deep, minutes: 45),
            SleepPeriod(type: .core, minutes: 48),
            SleepPeriod(type: .light, minutes: 120),
            SleepPeriod(type: .awake, minutes: 5),
            SleepPeriod(type: .deep, minutes: 90)
        ]
    )
    return List {
        SleepStageGraphView(day: day)
    }
}
