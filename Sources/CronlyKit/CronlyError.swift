import Foundation

public enum CronlyError: LocalizedError {
    case taskAlreadyExists(String)
    case taskNotFound(String)
    case invalidCronExpression(String)
    case launchdFailed(String)
    case wrapperScriptFailed(String)
    case invalidTaskName(String)
    case tooManyIntervals(Int)

    public var errorDescription: String? {
        switch self {
        case .taskAlreadyExists(let name):
            return "Task '\(name)' already exists"
        case .taskNotFound(let name):
            return "Task '\(name)' not found"
        case .invalidCronExpression(let expr):
            return "Invalid cron expression: \(expr)"
        case .launchdFailed(let msg):
            return "launchd error: \(msg)"
        case .wrapperScriptFailed(let msg):
            return "Wrapper script error: \(msg)"
        case .invalidTaskName(let msg):
            return "Invalid task name: \(msg)"
        case .tooManyIntervals(let count):
            return "Cron expression expands to \(count) intervals (max 500). Simplify the expression."
        }
    }
}
