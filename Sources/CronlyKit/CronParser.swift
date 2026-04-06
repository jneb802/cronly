import Foundation

/// Parses 5-field cron expressions into launchd StartCalendarInterval dicts.
/// Supports: numbers, *, */N, ranges (1-5), lists (1,3,5), and day-of-week names.
public enum CronParser {

    /// Parse a 5-field cron expression into one or more CalendarIntervals.
    /// launchd doesn't support */N natively for all fields, so we expand into multiple entries.
    public static func parse(_ expression: String) throws -> [[String: Int]] {
        let fields = expression.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
        guard fields.count == 5 else {
            throw CronlyError.invalidCronExpression("Expected 5 fields, got \(fields.count)")
        }

        let minutes = try expandField(fields[0], range: 0...59, name: "minute")
        let hours = try expandField(fields[1], range: 0...23, name: "hour")
        let days = try expandField(fields[2], range: 1...31, name: "day")
        let months = try expandField(fields[3], range: 1...12, name: "month")
        let weekdays = try expandField(fields[4], range: 0...6, name: "weekday")

        // Generate all combinations
        var intervals: [[String: Int]] = []
        for minute in minutes {
            for hour in hours {
                for day in days {
                    for month in months {
                        for weekday in weekdays {
                            var dict: [String: Int] = [:]
                            if let minute { dict["Minute"] = minute }
                            if let hour { dict["Hour"] = hour }
                            if let day { dict["Day"] = day }
                            if let month { dict["Month"] = month }
                            if let weekday { dict["Weekday"] = weekday }
                            intervals.append(dict)
                        }
                    }
                }
            }
        }

        if intervals.isEmpty {
            intervals.append([:])
        }

        guard intervals.count <= 500 else {
            throw CronlyError.tooManyIntervals(intervals.count)
        }

        return intervals
    }

    /// Returns nil for wildcard (*), concrete values otherwise
    private static func expandField(_ field: String, range: ClosedRange<Int>, name: String) throws -> [Int?] {
        if field == "*" {
            return [nil]
        }

        // Step values: */N
        if field.hasPrefix("*/") {
            guard let step = Int(field.dropFirst(2)), step > 0 else {
                throw CronlyError.invalidCronExpression("Invalid step in field '\(field)'")
            }
            return stride(from: range.lowerBound, through: range.upperBound, by: step).map { $0 }
        }

        // Lists: 1,3,5
        if field.contains(",") {
            return try field.split(separator: ",").map { part in
                guard let val = Int(part), range.contains(val) else {
                    throw CronlyError.invalidCronExpression("Invalid value '\(part)' in \(name)")
                }
                return val
            }
        }

        // Ranges: 1-5
        if field.contains("-") {
            let parts = field.split(separator: "-")
            guard parts.count == 2,
                  let low = Int(parts[0]),
                  let high = Int(parts[1]),
                  range.contains(low), range.contains(high),
                  low <= high else {
                throw CronlyError.invalidCronExpression("Invalid range '\(field)' in \(name)")
            }
            return (low...high).map { $0 }
        }

        // Single value
        guard let val = Int(field), range.contains(val) else {
            throw CronlyError.invalidCronExpression("Invalid value '\(field)' in \(name)")
        }
        return [val]
    }

    /// Human-readable description of a cron expression
    public static func describe(_ expression: String) -> String {
        let fields = expression.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
        guard fields.count == 5 else { return expression }

        let minute = fields[0]
        let hour = fields[1]
        let dom = fields[2]
        let month = fields[3]
        let dow = fields[4]

        // Common patterns
        if minute != "*" && hour != "*" && dom == "*" && month == "*" {
            let timeStr = formatTime(hour: hour, minute: minute)
            if dow == "*" {
                return "Every day at \(timeStr)"
            }
            if dow == "1-5" {
                return "Weekdays at \(timeStr)"
            }
            if dow == "0,6" {
                return "Weekends at \(timeStr)"
            }
            return "At \(timeStr) on day-of-week \(dow)"
        }

        if minute.hasPrefix("*/") {
            return "Every \(minute.dropFirst(2)) minutes"
        }

        if minute != "*" && hour == "*" {
            return "Every hour at minute \(minute)"
        }

        return expression
    }

    private static func formatTime(hour: String, minute: String) -> String {
        guard let h = Int(hour), let m = Int(minute) else { return "\(hour):\(minute)" }
        let period = h >= 12 ? "PM" : "AM"
        let displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return String(format: "%d:%02d %@", displayHour, m, period)
    }
}
