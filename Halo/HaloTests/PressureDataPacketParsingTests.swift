//
//  PressureDataPacketParsingTests.swift
//  HaloTests
//

import Testing
import Foundation
@testable import Halo

struct PressureDataPacketParsingTests {

    @Test("Pressure data header packet decodes expected count and range")
    func pressureHeaderPacketParsing() {
        let packet: [UInt8] = [55, 0, 24, 30]
        guard let parsed = SplitSeriesPacketParser.parse(packet) else {
            #expect(Bool(false))
            return
        }

        switch parsed {
        case let .header(expectedCount, rangeMinutes):
            #expect(expectedCount == 24)
            #expect(rangeMinutes == 30)
        case .values:
            #expect(Bool(false))
        case .noData:
            #expect(Bool(false))
        }
    }

    @Test("Pressure first data packet extracts values from byte 3")
    func pressureFirstDataPacketParsing() {
        let packet: [UInt8] = [55, 1, 24, 61, 0, 58, 55, 0, 60, 68, 56, 67, 62, 69, 224]
        guard let parsed = SplitSeriesPacketParser.parse(packet) else {
            #expect(Bool(false))
            return
        }

        switch parsed {
        case let .values(values):
            #expect(values == [61, 0, 58, 55, 0, 60, 68, 56, 67, 62, 69, 224])
        case .header:
            #expect(Bool(false))
        case .noData:
            #expect(Bool(false))
        }
    }

    @Test("Pressure continuation packet extracts values from byte 2 and builds series")
    func pressureContinuationPacketAndSeriesBuilding() {
        let packet: [UInt8] = [55, 2, 0, 45, 60, 0, 50, 0, 0, 0, 0, 0, 0, 0, 0]
        guard let parsed = SplitSeriesPacketParser.parse(packet) else {
            #expect(Bool(false))
            return
        }

        let values: [UInt8]
        switch parsed {
        case let .values(v):
            values = v
            #expect(values == [0, 45, 60, 0, 50, 0, 0, 0, 0, 0, 0, 0, 0])
        case .header:
            #expect(Bool(false))
            return
        case .noData:
            #expect(Bool(false))
            return
        }

        let startOfDay = Date(timeIntervalSince1970: 0)
        let series = SplitSeriesPacketParser.buildSeriesFromRaw(
            values,
            expectedCount: 4,
            rangeMinutes: 30,
            startOfDay: startOfDay
        )

        #expect(series.count == 2)
        #expect(series[0].value == 45)
        #expect(series[1].value == 60)
        #expect(series[0].time == startOfDay.addingTimeInterval(30 * 60))
        #expect(series[1].time == startOfDay.addingTimeInterval(60 * 60))
    }

    @Test("HRV no-data packet returns explicit noData")
    func hrvNoDataPacketParsing() {
        let packet: [UInt8] = [57, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 56]
        guard let parsed = SplitSeriesPacketParser.parse(packet) else {
            #expect(Bool(false))
            return
        }

        switch parsed {
        case .noData:
            #expect(Bool(true))
        case .header, .values:
            #expect(Bool(false))
        }
    }

    @Test("Split-series accumulator handles header data and reset")
    func splitSeriesAccumulatorFlow() {
        var accumulator = SplitSeriesPacketParser.SeriesAccumulator()

        let header: [UInt8] = [57, 0, 5, 30, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 92]
        let firstData: [UInt8] = [57, 1, 0, 51, 0, 56, 0, 46, 0, 44, 0, 55, 0, 51, 0, 105]
        let noData: [UInt8] = [57, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 56]

        let first = accumulator.consume(header)
        #expect(first == nil)

        let second = accumulator.consume(firstData)
        #expect(second != nil)
        #expect(second?.count == 3)
        #expect(second?.map(\.value) == [51, 56, 46])

        let third = accumulator.consume(noData)
        #expect(third?.isEmpty == true)
        #expect(accumulator.raw.isEmpty)
    }
}
