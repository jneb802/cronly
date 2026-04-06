import ArgumentParser
import CronlyKit

struct Add: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Add a new scheduled task"
    )

    @Option(name: .long, help: "Task name (used as identifier)")
    var name: String

    @Option(name: .long, help: "Shell command to execute")
    var command: String

    @Option(name: .long, help: "Cron expression (5 fields: min hour dom month dow)")
    var cron: String

    @Flag(name: .long, help: "Create the task in a disabled state")
    var disabled: Bool = false

    func run() throws {
        try Validation.validateTaskName(name)
        let _ = try CronParser.parse(cron)

        let task = TaskConfig(
            name: name,
            command: command,
            cronExpression: cron,
            enabled: !disabled
        )

        let store = ConfigStore()
        try store.addTask(task)

        let launchd = LaunchdManager()
        try launchd.install(task: task)

        let schedule = CronParser.describe(cron)
        print("Created task '\(name)'")
        print("  Schedule: \(schedule)")
        print("  Command:  \(command)")
        print("  Enabled:  \(!disabled)")
    }
}
