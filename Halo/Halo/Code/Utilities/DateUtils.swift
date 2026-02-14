//
//  DateUtils.swift
//  Halo
//
//  Created by Yannis De Cleene on 27/01/2025.
//

import Foundation

func startOfDay(for date: Date) -> Date? {
    let calendar = Calendar.current
    return calendar.startOfDay(for: date)
}

func endOfDay(for date: Date) -> Date? {
    guard let start = startOfDay(for: date) else { return nil }
    let calendar = Calendar.current
    return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start)
}

func datesBetween(start: Date, end: Date) throws -> [Date] {
    guard start <= end else {
        throw NSError(domain: "InvalidRange", code: 1, userInfo: [NSLocalizedDescriptionKey: "Start date is after end date"])
    }
    
    var dates: [Date] = []
    let calendar = Calendar.current
    var current = startOfDay(for: start)!
    
    while current <= end {
        dates.append(current)
        guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
        current = next
    }
    
    return dates
}

func now() -> Date {
    return Date()
}

func minutesSoFar(on date: Date) -> Int? {
    let calendar = Calendar.current
    guard let startOfDay = startOfDay(for: date) else { return nil }
    let elapsed = date.timeIntervalSince(startOfDay)
    return Int(elapsed / 60) + 1 // Adding 1 to match the Python behavior
}

func isToday(date: Date) -> Bool {
    let calendar = Calendar.current
    return calendar.isDateInToday(date)
}
