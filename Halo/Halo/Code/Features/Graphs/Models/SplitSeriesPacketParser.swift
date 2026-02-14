//
//  SplitSeriesPacketParser.swift
//  Halo
//
//  Shared parser for split-array series packets (HRV/Stress).
//

import Foundation

enum SplitSeriesPacketParser {
    enum ParsedPacket {
        case header(expectedCount: Int, rangeMinutes: Int)
        case values([UInt8])
        case noData
    }

    struct SeriesAccumulator {
        private(set) var expectedCount: Int = 0
        private(set) var rangeMinutes: Int = 30
        private(set) var raw: [UInt8] = []

        mutating func reset() {
            expectedCount = 0
            rangeMinutes = 30
            raw = []
        }

        mutating func consume(_ packet: [UInt8]) -> [TimeSeriesPoint]? {
            guard let parsed = SplitSeriesPacketParser.parse(packet) else { return nil }
            switch parsed {
            case let .header(expectedCount, rangeMinutes):
                self.expectedCount = expectedCount
                self.rangeMinutes = rangeMinutes
                raw = []
                return nil
            case let .values(values):
                raw.append(contentsOf: values)
                return SplitSeriesPacketParser.buildSeriesFromRaw(
                    raw,
                    expectedCount: expectedCount,
                    rangeMinutes: rangeMinutes
                )
            case .noData:
                reset()
                return []
            }
        }
    }

    /// Parses one split-array payload packet used by command 57 (HRV) and 55 (Stress).
    static func parse(_ packet: [UInt8]) -> ParsedPacket? {
        guard packet.count >= 4 else { return nil }
        let index = Int(packet[1])
        if index == 255 {
            return .noData
        }
        if index == 0 {
            let expectedCount = Int(packet[2])
            let rangeMinutes = max(1, Int(packet[3]))
            return .header(expectedCount: expectedCount, rangeMinutes: rangeMinutes)
        }

        let values: [UInt8]
        if index == 1 {
            values = Array(packet[3..<min(packet.count, 15)])
        } else {
            values = Array(packet[2..<min(packet.count, 15)])
        }
        return .values(values)
    }

    static func buildSeriesFromRaw(
        _ raw: [UInt8],
        expectedCount: Int,
        rangeMinutes: Int,
        startOfDay: Date = Calendar.current.startOfDay(for: Date())
    ) -> [TimeSeriesPoint] {
        // In real ring payloads for commands 55/57, header[2] is not reliable as a strict
        // "number of usable samples". Truncating to that value drops valid points.
        _ = expectedCount
        let values = raw
        return values.enumerated().map { idx, v in
            let t = startOfDay.addingTimeInterval(TimeInterval(idx * rangeMinutes * 60))
            return TimeSeriesPoint(time: t, value: Double(v))
        }.filter { $0.value > 0 }
    }
}
