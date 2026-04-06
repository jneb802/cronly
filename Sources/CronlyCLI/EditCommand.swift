import ArgumentParser
import CronlyKit

struct EditCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "edit",
        abstract: "Edit an existing task"
    )

    @Argument(help: "Task name to edit")
    var name: String

    @Option(name: .long, help: "New shell command")
    var command: String?

    @Option(name: .long, help: "New cron expression")
    var cron: String?

    @Option(name: .customLong("name"), help: "Rename the task")
    var newName: String?

    func run() throws {
        if let newName {
            try Validation.validateTaskName(newName)
        }
        if cron != nil {
            let _ = try CronParser.parse(cron!)
        }

        let store = ConfigStore()

        if let newName {
            // Rename: add new first (safe — fails if name taken), then remove old
            let oldTask = try store.getTask(name: name)
            let updated = TaskConfig(
                name: newName,
                command: command ?? oldTask.command,
                cronExpression: cron ?? oldTask.cronExpression,
                enabled: oldTask.enabled
            )
            try store.addTask(updated)

            let launchd = LaunchdManager()
            try launchd.uninstall(name: name)
            try store.removeTask(name: name)
            try launchd.install(task: updated)
            print("Renamed '\(name)' to '\(newName)'")
        } else {
            try store.updateTask(name: name) { task in
                if let command { task.command = command }
                if let cron { task.cronExpression = cron }
            }

            let task = try store.getTask(name: name)
            let launchd = LaunchdManager()
            try launchd.install(task: task)
            print("Updated task '\(name)'")
        }
    }
}
