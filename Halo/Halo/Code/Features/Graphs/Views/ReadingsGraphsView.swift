//
//  ReadingsGraphsView.swift
//  Halo
//
//  Graphs tab: sleep, heart rate, activity, HRV, blood oxygen, stress.
//

import SwiftUI
import SwiftData

struct ReadingsGraphsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var ringSessionManager: RingSessionManager
    private let includeActivitySection: Bool
    @Query(sort: \StoredSleepDay.syncDate, order: .reverse) private var storedSleepDays: [StoredSleepDay]
    @Query(sort: \StoredHeartRateLog.timestamp, order: .reverse) private var storedHeartRateLogs: [StoredHeartRateLog]
    @Query(sort: \StoredActivitySample.timestamp, order: .reverse) private var storedActivitySamples: [StoredActivitySample]
    @Query(sort: \StoredHRVSample.timestamp, order: .reverse) private var storedHRVSamples: [StoredHRVSample]
    @Query(sort: \StoredBloodOxygenSample.timestamp, order: .reverse) private var storedBloodOxygenSamples: [StoredBloodOxygenSample]
    @Query(sort: \StoredStressSample.timestamp, order: .reverse) private var storedStressSamples: [StoredStressSample]

    @State private var hrvSeriesAccumulator = SplitSeriesPacketParser.SeriesAccumulator()
    @State private var stressSeriesAccumulator = SplitSeriesPacketParser.SeriesAccumulator()
    @State private var selectedWeekOffset: Int = 0
    @State private var selectedDate: Date = Date()
    @State private var visibleWeekOffset: Int?

    private let maxPastWeeks = 104
    private static let swiftDataLogDateFormatter = ISO8601DateFormatter()

    private var sortedSleepDays: [StoredSleepDay] {
        storedSleepDays.sorted { $0.sleepDate > $1.sleepDate }
    }

    private var selectedSleepDays: [StoredSleepDay] {
        sortedSleepDays.filter { mondayCalendar.isDate($0.sleepDate, inSameDayAs: selectedDayStart) }
    }

    private var selectedSleepDay: StoredSleepDay? {
        selectedSleepDays.first
    }

    private var mondayCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private var todayStart: Date {
        mondayCalendar.startOfDay(for: Date())
    }

    private var currentWeekStart: Date {
        let comps = mondayCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: todayStart)
        return mondayCalendar.date(from: comps) ?? todayStart
    }

    private var selectedDayStart: Date {
        mondayCalendar.startOfDay(for: selectedDate)
    }

    private var selectedDayEnd: Date {
        mondayCalendar.date(byAdding: .day, value: 1, to: selectedDayStart) ?? selectedDayStart.addingTimeInterval(24 * 60 * 60)
    }

    private var selectedDayHeartRateLogs: [StoredHeartRateLog] {
        storedHeartRateLogs
            .filter { isWithinSelectedDay($0.dayStart) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var selectedDayActivitySamples: [StoredActivitySample] {
        storedActivitySamples
            .filter { isWithinSelectedDay($0.timestamp) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var selectedDayHRVSamples: [StoredHRVSample] {
        storedHRVSamples
            .filter { isWithinSelectedDay($0.timestamp) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var selectedDayBloodOxygenSamples: [StoredBloodOxygenSample] {
        storedBloodOxygenSamples
            .filter { isWithinSelectedDay($0.timestamp) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var selectedDayStressSamples: [StoredStressSample] {
        storedStressSamples
            .filter { isWithinSelectedDay($0.timestamp) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var weekOffsets: [Int] {
        Array(stride(from: maxPastWeeks, through: 0, by: -1))
    }

    init(ringSessionManager: RingSessionManager, includeActivitySection: Bool = true) {
        self.ringSessionManager = ringSessionManager
        self.includeActivitySection = includeActivitySection
    }

    private var activityStepsData: [TimeSeriesPoint] {
        return selectedDayActivitySamples
            .map { TimeSeriesPoint(time: $0.timestamp, value: Double($0.steps)) }
    }

    private var activityDistanceData: [TimeSeriesPoint] {
        return selectedDayActivitySamples
            .map { TimeSeriesPoint(time: $0.timestamp, value: $0.distanceKm) }
    }

    private var activityCaloriesData: [TimeSeriesPoint] {
        return selectedDayActivitySamples
            .map { TimeSeriesPoint(time: $0.timestamp, value: Double($0.calories)) }
    }

    private var hrvData: [TimeSeriesPoint] {
        return selectedDayHRVSamples
            .map { TimeSeriesPoint(time: $0.timestamp, value: $0.value) }
    }

    private var bloodOxygenData: [TimeSeriesPoint] {
        return selectedDayBloodOxygenSamples
            .map { TimeSeriesPoint(time: $0.timestamp, value: $0.value) }
    }

    private var stressData: [TimeSeriesPoint] {
        return selectedDayStressSamples
            .map { TimeSeriesPoint(time: $0.timestamp, value: $0.value) }
    }

    var body: some View {
        NavigationStack {
            List {
                weekPickerSection
                sleepSection
                heartRateSection
                if includeActivitySection {
                    activitySection
                }
                hrvSection
                bloodOxygenSection
                stressSection
                realTimeTrackingSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.Graphs.navTitle)
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                selectedDate = todayStart
                visibleWeekOffset = selectedWeekOffset
                wireLiveMetricCallbacks()
            }
        }
    }

    private var weekPickerSection: some View {
        Section {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(weekOffsets, id: \.self) { weekOffset in
                        weekRow(for: weekOffset)
                            .id(weekOffset)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $visibleWeekOffset, anchor: .center)
            .onChange(of: visibleWeekOffset) { _, newValue in
                guard let newValue else { return }
                let weekday = weekdayIndex(for: selectedDate, weekStart: weekStart(for: selectedWeekOffset))
                selectedWeekOffset = newValue
                moveSelectedDateToCurrentDisplayedWeek(weekdayIndex: weekday)
            }
        }
    }

    @ViewBuilder
    private func weekRow(for weekOffset: Int) -> some View {
        let weekStart = weekStart(for: weekOffset)
        let dates = weekDates(for: weekOffset)
        HStack(spacing: 8) {
            ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                let selected = weekOffset == selectedWeekOffset && mondayCalendar.isDate(date, inSameDayAs: selectedDayStart)
                let isFuture = date > todayStart
                Button {
                    guard !isFuture else { return }
                    selectedWeekOffset = weekOffset
                    visibleWeekOffset = weekOffset
                    selectedDate = mondayCalendar.startOfDay(for: date)
                } label: {
                    VStack(spacing: 6) {
                        Text(date, format: .dateTime.weekday(.abbreviated))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isFuture ? .tertiary : .secondary)
                        Text(date, format: .dateTime.day())
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(
                                selected ? Color.white : (isFuture ? Color.gray : Color.primary)
                            )
                            .frame(width: 34, height: 34)
                            .background(selected ? Color.purple : Color.clear)
                            .clipShape(Circle())
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isFuture)
                .buttonStyle(.plain)
                .accessibilityLabel(Text(date, format: .dateTime.weekday(.wide).day().month().year()))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
        .onAppear {
            // Keep selection valid if user scrolls far while focused on a future day in current week.
            if weekOffset == 0 && selectedDayStart > todayStart {
                selectedDate = todayStart
            }
        }
        .id(weekStart)
    }

    // MARK: - Sleep

    private var sleepSection: some View {
        Section {
            if let storedDay = selectedSleepDay {
                let day = storedDay.toSleepDay()
                VStack(alignment: .leading, spacing: 16) {
                    SleepChartKitView(day: day, nightDate: storedDay.sleepDate)
                    SleepStageGraphView(day: day)
                }
                .padding(.vertical, 8)
            } else {
                emptyStateView(message: L10n.Graphs.noSleepData)
            }
        } header: {
            Label(L10n.Graphs.sleepSection, systemImage: "bed.double.fill")
        }
    }

    private func moveSelectedDateToCurrentDisplayedWeek(weekdayIndex: Int) {
        guard let target = mondayCalendar.date(byAdding: .day, value: weekdayIndex, to: weekStart(for: selectedWeekOffset)) else { return }
        let start = mondayCalendar.startOfDay(for: target)
        if selectedWeekOffset == 0 && start > todayStart {
            selectedDate = todayStart
        } else {
            selectedDate = start
        }
    }

    private func weekStart(for weekOffset: Int) -> Date {
        mondayCalendar.date(byAdding: .day, value: -7 * weekOffset, to: currentWeekStart) ?? currentWeekStart
    }

    private func weekDates(for weekOffset: Int) -> [Date] {
        let start = weekStart(for: weekOffset)
        return (0..<7).compactMap { mondayCalendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func weekdayIndex(for date: Date, weekStart: Date) -> Int {
        let start = mondayCalendar.startOfDay(for: weekStart)
        let selected = mondayCalendar.startOfDay(for: date)
        let delta = mondayCalendar.dateComponents([.day], from: start, to: selected).day ?? 0
        return min(max(delta, 0), 6)
    }

    // MARK: - Heart rate

    private var heartRateSection: some View {
        Section {
            if selectedDayHeartRateLogs.isEmpty {
                emptyStateView(message: L10n.Graphs.noHeartRateData)
            } else {
                if let log = selectedHeartRateLog {
                    heartRateDetailChart(log: log)
                }
            }
        } header: {
            Label(L10n.Graphs.heartRateSection, systemImage: "heart.fill")
        }
    }

    private var selectedHeartRateLog: StoredHeartRateLog? {
        selectedDayHeartRateLogs.first
    }

    private func heartRateDetailChart(log: StoredHeartRateLog) -> some View {
        let points: [HeartRateDataPoint] = (try? log.toHeartRateLog().heartRatesWithTimes())
            .map { $0.map { HeartRateDataPoint(heartRate: $0.0, time: $0.1) } } ?? []
        return VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Graphs.heartRateIntervals)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            if points.isEmpty {
                Text(L10n.Graphs.noValidReadings)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                HeartRateGraphView(data: points)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Activity

    private var activitySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                if activityStepsData.isEmpty || activityDistanceData.isEmpty || activityCaloriesData.isEmpty {
                    Text(L10n.Graphs.sampleActivity)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ActivityStepsChartView(data: activityStepsData)
                    ActivityStepsCumulativeComparisonChartView(
                        comparisonData: PreviewData.stepsPerHourWeeklyAverage,
                        data: activityStepsData
                    )
                    ActivityDistanceChartView(data: activityDistanceData)
                    ActivityDistanceCumulativeComparisonChartView(
                        comparisonData: PreviewData.distancePerHourWeeklyAverage,
                        data: activityDistanceData
                    )
                    ActivityCaloriesChartView(data: activityCaloriesData)
                    ActivityCaloriesCumulativeComparisonChartView(
                        comparisonData: PreviewData.caloriesPerHourWeeklyAverage,
                        data: activityCaloriesData
                    )
                }
            }
        } header: {
            Label(L10n.Graphs.activitySection, systemImage: "figure.walk")
        }
    }

    // MARK: - HRV

    private var hrvSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                if hrvData.isEmpty {
                    Text(L10n.Graphs.sampleHRV)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    HRVChartView(data: hrvData)
                }
            }
        } header: {
            Label(L10n.Graphs.hrvSection, systemImage: "waveform.path.ecg")
        }
    }

    // MARK: - Blood oxygen

    private var bloodOxygenSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                if bloodOxygenData.isEmpty {
                    Text(L10n.Graphs.sampleBloodOxygen)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    BloodOxygenChartView(data: bloodOxygenData)
                }
            }
        } header: {
            Label(L10n.Graphs.bloodOxygenSection, systemImage: "drop.fill")
        }
    }

    // MARK: - Stress

    private var stressSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                if stressData.isEmpty {
                    Text(L10n.Graphs.sampleStress)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    StressChartView(data: stressData)
                }
            }
        } header: {
            Label(L10n.Graphs.stressSection, systemImage: "leaf.fill")
        }
    }

    // MARK: - Real-time tracking

    private var realTimeTrackingSection: some View {
        Section {
            VStack(spacing: 12) {
                realTimeTrackingCard(
                    title: L10n.Graphs.heartRateSection,
                    systemImage: "heart.fill",
                    valueText: ringSessionManager.realTimeHeartRateBPM.map { "\($0) \(L10n.HomeSummary.bpm)" } ?? L10n.HomeSummary.noData,
                    startTitle: L10n.HeartRate.streamingStart,
                    continueTitle: L10n.HeartRate.streamingContinue,
                    stopTitle: L10n.HeartRate.streamingStop,
                    startA11y: L10n.A11y.heartRateStart,
                    continueA11y: L10n.A11y.heartRateContinue,
                    stopA11y: L10n.A11y.heartRateStop,
                    onStart: { ringSessionManager.startRealTimeStreaming(type: .heartRate) },
                    onContinue: { ringSessionManager.continueRealTimeStreaming(type: .heartRate) },
                    onStop: { ringSessionManager.stopRealTimeStreaming(type: .heartRate) }
                )
                realTimeTrackingCard(
                    title: L10n.Graphs.bloodOxygenSection,
                    systemImage: "drop.fill",
                    valueText: ringSessionManager.realTimeBloodOxygenPercent.map { "\($0)%" } ?? L10n.HomeSummary.noData,
                    startTitle: L10n.SPO2.streamingStart,
                    continueTitle: L10n.SPO2.streamingContinue,
                    stopTitle: L10n.SPO2.streamingStop,
                    startA11y: L10n.A11y.spo2Start,
                    continueA11y: L10n.A11y.spo2Continue,
                    stopA11y: L10n.A11y.spo2Stop,
                    onStart: { ringSessionManager.startRealTimeStreaming(type: .spo2) },
                    onContinue: { ringSessionManager.continueRealTimeStreaming(type: .spo2) },
                    onStop: { ringSessionManager.stopRealTimeStreaming(type: .spo2) }
                )
            }
            .padding(.vertical, 4)
        } header: {
            Label(L10n.Graphs.realtimeSection, systemImage: "waveform.path.ecg")
        }
    }

    private func realTimeTrackingCard(
        title: String,
        systemImage: String,
        valueText: String,
        startTitle: String,
        continueTitle: String,
        stopTitle: String,
        startA11y: String,
        continueA11y: String,
        stopA11y: String,
        onStart: @escaping () -> Void,
        onContinue: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(valueText)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                realtimeButton(
                    title: startTitle,
                    color: .green,
                    accessibilityLabel: startA11y,
                    action: onStart
                )
                realtimeButton(
                    title: continueTitle,
                    color: .orange,
                    accessibilityLabel: continueA11y,
                    action: onContinue
                )
                realtimeButton(
                    title: stopTitle,
                    color: .red,
                    accessibilityLabel: stopA11y,
                    action: onStop
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func realtimeButton(
        title: String,
        color: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!ringSessionManager.peripheralConnected)
        .accessibilityLabel(accessibilityLabel)
    }

    private func wireLiveMetricCallbacks() {
        // Auto-persistence is wired globally by RingDataPersistenceCoordinator in HaloApp.
        // Keep only the explicit refresh requests when opening the Graphs screen.
        if ringSessionManager.peripheralConnected {
            ringSessionManager.syncActivityData(dayOffset: 0)
            ringSessionManager.syncHRVData(dayOffset: 0)
            ringSessionManager.syncBloodOxygen(dayOffset: 0)
            ringSessionManager.syncPressureData(dayOffset: 0)
        }
    }

    private func todayAtHour(_ hour: Int) -> Date {
        Calendar.current.date(bySettingHour: max(0, min(23, hour)), minute: 0, second: 0, of: Date()) ?? Date()
    }

    private func consumeActivityPacket(_ packet: [UInt8]) {
        // Commands 67 (SportsData): [cmd, year, month, day, time, calories(2), steps(2), distance(2), ...]
        guard packet.count >= 11, packet[0] == 67 else { return }
        let hour = Int(packet[4])
        // SportsDataResponse fields are uint16 and ring payload uses little-endian across this protocol.
        let calories = Int(packet[5]) | (Int(packet[6]) << 8)
        let steps = Int(packet[7]) | (Int(packet[8]) << 8)
        let distanceRaw = Int(packet[9]) | (Int(packet[10]) << 8)
        let distanceKm = Double(distanceRaw) / 100.0

        upsertStoredActivitySample(timestamp: todayAtHour(hour), steps: steps, distanceKm: distanceKm, calories: calories)
    }

    private func consumeSplitSeriesPacket(_ packet: [UInt8], isHRV: Bool) {
        // Commands 57 (HRV) / 55 (Pressure): split array format.
        if isHRV {
            guard let series = hrvSeriesAccumulator.consume(packet) else { return }
            persistHRVSeries(series)
        } else {
            guard let series = stressSeriesAccumulator.consume(packet) else { return }
            persistStressSeries(series)
        }
    }

    private func consumeBloodOxygenPayload(_ payload: [UInt8]) {
        let decoded = decodeBigDataBloodOxygen(payload)
        if !decoded.isEmpty {
            persistBloodOxygenSeries(decoded)
        }
    }

    private func upsertStoredActivitySample(timestamp: Date, steps: Int, distanceKm: Double, calories: Int) {
        let action: String
        if let existing = storedActivitySamples.first(where: { $0.timestamp == timestamp }) {
            existing.steps = steps
            existing.distanceKm = distanceKm
            existing.calories = calories
            action = "UPDATE"
        } else {
            modelContext.insert(StoredActivitySample(timestamp: timestamp, steps: steps, distanceKm: distanceKm, calories: calories))
            action = "INSERT"
        }
        debugPrint("========== SWIFTDATA SAVE: Activity ==========")
        debugPrint("action: \(action)")
        debugPrint("timestamp: \(swiftDataLogDate(timestamp))")
        debugPrint("steps: \(steps), distanceKm: \(distanceKm), calories: \(calories)")
        do {
            try modelContext.save()
            debugPrint("result: SUCCESS")
        } catch {
            debugPrint("result: FAILED - \(error)")
        }
        debugPrint("==============================================")
    }

    private func persistHRVSeries(_ series: [TimeSeriesPoint]) {
        var inserted: [TimeSeriesPoint] = []
        var updated: [TimeSeriesPoint] = []
        for point in series {
            if let existing = storedHRVSamples.first(where: { $0.timestamp == point.time }) {
                existing.value = point.value
                updated.append(point)
            } else {
                modelContext.insert(StoredHRVSample(timestamp: point.time, value: point.value))
                inserted.append(point)
            }
        }
        debugPrint("============ SWIFTDATA SAVE: HRV =============")
        debugPrint("inserted: \(inserted.count), updated: \(updated.count), totalSeriesPoints: \(series.count)")
        debugPrint("insertedPoints: \(formatSeriesPointsForLog(inserted))")
        debugPrint("updatedPoints: \(formatSeriesPointsForLog(updated))")
        do {
            try modelContext.save()
            debugPrint("result: SUCCESS")
        } catch {
            debugPrint("result: FAILED - \(error)")
        }
        debugPrint("==============================================")
    }

    private func persistBloodOxygenSeries(_ series: [TimeSeriesPoint]) {
        var inserted: [TimeSeriesPoint] = []
        var updated: [TimeSeriesPoint] = []
        for point in series {
            if let existing = storedBloodOxygenSamples.first(where: { $0.timestamp == point.time }) {
                existing.value = point.value
                updated.append(point)
            } else {
                modelContext.insert(StoredBloodOxygenSample(timestamp: point.time, value: point.value))
                inserted.append(point)
            }
        }
        debugPrint("====== SWIFTDATA SAVE: Blood Oxygen ======")
        debugPrint("inserted: \(inserted.count), updated: \(updated.count), totalSeriesPoints: \(series.count)")
        debugPrint("insertedPoints: \(formatSeriesPointsForLog(inserted))")
        debugPrint("updatedPoints: \(formatSeriesPointsForLog(updated))")
        do {
            try modelContext.save()
            debugPrint("result: SUCCESS")
        } catch {
            debugPrint("result: FAILED - \(error)")
        }
        debugPrint("==========================================")
    }

    private func persistStressSeries(_ series: [TimeSeriesPoint]) {
        var inserted: [TimeSeriesPoint] = []
        var updated: [TimeSeriesPoint] = []
        for point in series {
            if let existing = storedStressSamples.first(where: { $0.timestamp == point.time }) {
                existing.value = point.value
                updated.append(point)
            } else {
                modelContext.insert(StoredStressSample(timestamp: point.time, value: point.value))
                inserted.append(point)
            }
        }
        debugPrint("=========== SWIFTDATA SAVE: Stress ===========")
        debugPrint("inserted: \(inserted.count), updated: \(updated.count), totalSeriesPoints: \(series.count)")
        debugPrint("insertedPoints: \(formatSeriesPointsForLog(inserted))")
        debugPrint("updatedPoints: \(formatSeriesPointsForLog(updated))")
        do {
            try modelContext.save()
            debugPrint("result: SUCCESS")
        } catch {
            debugPrint("result: FAILED - \(error)")
        }
        debugPrint("==============================================")
    }

    private func swiftDataLogDate(_ date: Date) -> String {
        Self.swiftDataLogDateFormatter.string(from: date)
    }

    private func formatSeriesPointsForLog(_ points: [TimeSeriesPoint]) -> String {
        guard !points.isEmpty else { return "[]" }
        let values = points.map { point in
            "{time: \(swiftDataLogDate(point.time)), value: \(point.value)}"
        }
        return "[\(values.joined(separator: ", "))]"
    }

    private func decodeBigDataBloodOxygen(_ payload: [UInt8]) -> [TimeSeriesPoint] {
        guard payload.count >= 4 else { return [] }

        // Candidate A: concatenated day blocks.
        // Seen on some firmware as repeated blocks in one payload (multi-day response).
        // We support common block sizes and pick the decode with most valid points.
        let multiDayCandidates = [50, 49, 48].compactMap { blockSize in
            decodeBloodOxygenFixedBlocks(payload, blockSize: blockSize)
        }
        if let best = multiDayCandidates.max(by: { $0.count < $1.count }), best.count >= 24 {
            return best
        }

        // Candidate B: documented single-day payload: [unk, daysAgo, (min,max)...]
        let daysAgo = Int(payload[1])
        let sampleBytes = Array(payload.dropFirst(2))
        let singleDay = decodeBloodOxygenDaySamples(sampleBytes, daysAgo: daysAgo)
        if !singleDay.isEmpty {
            return singleDay
        }

        return []
    }

    private func decodeBloodOxygenFixedBlocks(_ payload: [UInt8], blockSize: Int) -> [TimeSeriesPoint]? {
        guard blockSize >= 4, payload.count % blockSize == 0 else { return nil }
        let blockCount = payload.count / blockSize
        guard blockCount > 1 else { return nil }

        var result: [TimeSeriesPoint] = []
        var offset = 0
        for _ in 0..<blockCount {
            let block = Array(payload[offset..<(offset + blockSize)])
            offset += blockSize
            guard block.count >= 3 else { return nil }

            let daysAgo = Int(block[1])
            let dayBytes = Array(block.dropFirst(2))

            // If odd-sized day bytes, treat first byte as optional count/marker and decode the remainder.
            let normalized: [UInt8]
            if dayBytes.count % 2 == 1, dayBytes.count > 3 {
                normalized = Array(dayBytes.dropFirst())
            } else {
                normalized = dayBytes
            }

            let points = decodeBloodOxygenDaySamples(normalized, daysAgo: daysAgo)
            if points.isEmpty { return nil }
            result.append(contentsOf: points)
        }
        return result
    }

    private func decodeBloodOxygenDaySamples(_ sampleBytes: [UInt8], daysAgo: Int) -> [TimeSeriesPoint] {
        guard sampleBytes.count >= 2 else { return [] }

        // Primary: min/max pairs (hourly averages) as documented.
        if sampleBytes.count % 2 == 0 {
            var points: [TimeSeriesPoint] = []
            var hour = 0
            var i = 0
            while i + 1 < sampleBytes.count, hour < 24 {
                let minV = Double(sampleBytes[i])
                let maxV = Double(sampleBytes[i + 1])
                let avg = (minV + maxV) / 2.0
                points.append(TimeSeriesPoint(time: dayAtHour(daysAgo: daysAgo, hour: hour), value: avg))
                i += 2
                hour += 1
            }
            return points.filter { $0.value > 0 }
        }

        // Fallback: single-value samples with 30-minute interval.
        return sampleBytes.enumerated().map { idx, value in
            let hour = idx / 2
            let minute = (idx % 2) * 30
            return TimeSeriesPoint(time: dayAtTime(daysAgo: daysAgo, hour: hour, minute: minute), value: Double(value))
        }.filter { $0.value > 0 }
    }

    private func dayAtHour(daysAgo: Int, hour: Int) -> Date {
        dayAtTime(daysAgo: daysAgo, hour: hour, minute: 0)
    }

    private func dayAtTime(daysAgo: Int, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        return calendar.date(bySettingHour: max(0, min(23, hour)), minute: max(0, min(59, minute)), second: 0, of: day) ?? day
    }

    private func emptyStateView(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
    }

    private func isWithinSelectedDay(_ date: Date) -> Bool {
        let candidate = mondayCalendar.startOfDay(for: date)
        return candidate >= selectedDayStart && candidate < selectedDayEnd
    }
}

#Preview {
    ReadingsGraphsView(ringSessionManager: RingSessionManager())
        .modelContainer(
            for: [
                StoredSleepDay.self,
                StoredSleepPeriod.self,
                StoredHeartRateLog.self,
                StoredActivitySample.self,
                StoredHRVSample.self,
                StoredBloodOxygenSample.self,
                StoredStressSample.self
            ],
            inMemory: true
        )
}
