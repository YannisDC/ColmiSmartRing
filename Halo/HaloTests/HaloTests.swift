//
//  HaloTests.swift
//  HaloTests
//
//  Created by Yannis De Cleene on 13/02/2026.
//

import Testing
import Foundation
@testable import Halo

struct HaloTests {

    @Test("Big Data sleep request packet uses expected wire format")
    func bigDataSleepRequestPacketEncoding() {
        let packet = RingSessionManager.makeBigDataRequestPacket(dataId: 39)
        #expect(packet == [188, 39, 0, 0, 0xFF, 0xFF])
    }

    @Test("Big Data response header parse returns sleep payload")
    func bigDataResponsePacketDecoding() {
        let payload: [UInt8] = [2, 1, 8, 100, 5, 200, 1, 2, 30, 3, 18, 0, 6, 120, 5, 44, 2, 5, 10]
        let frame: [UInt8] = [188, 39, 19, 0, 0x79, 0xED] + payload
        let parsed = RingSessionManager.parseBigDataResponsePacket(frame)

        #expect(parsed != nil)
        #expect(parsed?.dataId == 39)
        #expect(parsed?.dataLen == payload.count)
        #expect(parsed?.crc16 == 0xED79)
        #expect(parsed?.payload == payload)
    }

    @Test("Sleep Big Data payload parser decodes multi-day payload and periods in order")
    func sleepBigDataPayloadParsingMultiDay() {
        // sleepDays=2
        // day 1: daysAgo=1, curDayBytes=8, start=1380 (23:00), end=456 (07:36), periods: (light,30),(deep,18)
        // day 2: daysAgo=0, curDayBytes=6, start=1400 (23:20), end=556 (09:16), periods: (awake,10)
        let payload: [UInt8] = [
            2,
            1, 8, 100, 5, 200, 1, 2, 30, 3, 18,
            0, 6, 120, 5, 44, 2, 5, 10
        ]

        let parsed = BigDataSleepParser.parseSleepPayload(payload)
        #expect(parsed != nil)
        #expect(parsed?.sleepDays == 2)
        #expect(parsed?.days.count == 2)

        let day1 = parsed?.days[0]
        #expect(day1?.daysAgo == 1)
        #expect(day1?.curDayBytes == 8)
        #expect(day1?.sleepStart == 1380)
        #expect(day1?.sleepEnd == 456)
        #expect(day1?.periods.count == 2)
        #expect(day1?.periods[0].type == .light)
        #expect(day1?.periods[0].minutes == 30)
        #expect(day1?.periods[1].type == .deep)
        #expect(day1?.periods[1].minutes == 18)

        let day2 = parsed?.days[1]
        #expect(day2?.daysAgo == 0)
        #expect(day2?.curDayBytes == 6)
        #expect(day2?.sleepStart == 1400)
        #expect(day2?.sleepEnd == 556)
        #expect(day2?.periods.count == 1)
        #expect(day2?.periods[0].type == .awake)
        #expect(day2?.periods[0].minutes == 10)
    }

    @Test("Heart rate parser decodes log packets from captured stream")
    func heartRateParserDecodesCapturedPackets() {
        let packets: [[UInt8]] = [
            [21, 0, 24, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 50],
            [21, 1, 128, 105, 142, 105, 91, 0, 0, 0, 0, 0, 94, 0, 0, 175],
            [21, 2, 0, 0, 0, 61, 0, 0, 0, 0, 0, 58, 0, 0, 0, 142],
            [21, 3, 0, 0, 55, 0, 0, 0, 0, 0, 60, 0, 0, 0, 0, 139],
            [21, 4, 0, 68, 0, 0, 0, 0, 0, 56, 0, 0, 0, 0, 0, 149],
            [21, 5, 67, 0, 0, 0, 0, 0, 62, 0, 0, 0, 0, 0, 69, 224],
            [21, 6, 0, 0, 0, 0, 0, 57, 0, 0, 0, 0, 0, 98, 0, 182],
            [21, 7, 0, 0, 0, 0, 73, 0, 0, 0, 0, 0, 62, 0, 0, 163],
            [21, 8, 0, 0, 0, 99, 0, 0, 0, 0, 0, 68, 0, 0, 0, 196],
            [21, 9, 0, 0, 85, 0, 0, 0, 0, 0, 93, 0, 0, 0, 0, 208],
            [21, 10, 0, 87, 0, 0, 0, 0, 0, 81, 0, 0, 0, 0, 0, 199],
            [21, 11, 85, 0, 0, 0, 0, 0, 94, 0, 0, 0, 0, 0, 77, 32],
            [21, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 33],
            [21, 13, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 34],
            [21, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35],
            [21, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 36],
            [21, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 37],
            [21, 17, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 38],
            [21, 18, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 39],
            [21, 19, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 40],
            [21, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 41],
            [21, 21, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 42],
            [21, 22, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 43],
            [21, 23, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 44]
        ]

        let parser = HeartRateLogParser()
        var parsedLog: HeartRateLog?
        for packet in packets {
            if let log = parser.parse(packet: packet) as? HeartRateLog {
                parsedLog = log
            }
        }

        #expect(parsedLog != nil)
        #expect(parsedLog?.size == 24)
        #expect(parsedLog?.range == 5)
        #expect(parsedLog?.index == 295)
        #expect(parsedLog?.timestamp == Date(timeIntervalSince1970: 1770940800))
        #expect(parsedLog?.heartRates.count == 288)

        let nonZero = parsedLog?.heartRates.filter { $0 > 0 } ?? []
        #expect(nonZero == [91, 94, 61, 58, 55, 60, 68, 56, 67, 62, 69, 57, 98, 73, 62, 99, 68, 85, 93, 87, 81, 85, 94, 77])
    }

}
