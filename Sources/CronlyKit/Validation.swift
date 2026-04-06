import Foundation

public enum Validation {
    private static let validNamePattern = try! NSRegularExpression(pattern: "^[a-zA-Z0-9_-]+$")

    /// Validate task name: alphanumeric, dashes, underscores only
    public static func validateTaskName(_ name: String) throws {
        guard !name.isEmpty else {
            throw CronlyError.invalidTaskName("name cannot be empty")
        }
        guard name.count <= 64 else {
            throw CronlyError.invalidTaskName("name too long (max 64 characters)")
        }
        let range = NSRange(name.startIndex..., in: name)
        guard validNamePattern.firstMatch(in: name, range: range) != nil else {
            throw CronlyError.invalidTaskName("'\(name)' — only letters, numbers, dashes, and underscores allowed")
        }
    }
}
