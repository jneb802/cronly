import Foundation

public struct TaskConfig: Codable, Identifiable {
    public var id: String { name }
    public var name: String
    public var command: String
    public var cronExpression: String
    public var enabled: Bool

    public init(name: String, command: String, cronExpression: String, enabled: Bool = true) {
        self.name = name
        self.command = command
        self.cronExpression = cronExpression
        self.enabled = enabled
    }
}

public struct CronlyConfig: Codable {
    public var tasks: [TaskConfig]

    public init(tasks: [TaskConfig] = []) {
        self.tasks = tasks
    }
}
