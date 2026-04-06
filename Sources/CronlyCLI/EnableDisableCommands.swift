import ArgumentParser
import CronlyKit

struct Enable: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Enable a task"
    )

    @Argument(help: "Task name to enable")
    var name: String

    func run() throws {
        let store = ConfigStore()
        try store.updateTask(name: name) { task in
            task.enabled = true
        }

        let launchd = LaunchdManager()
        let task = try store.getTask(name: name)
        try launchd.install(task: task)
        print("Enabled task '\(name)'")
    }
}

struct Disable: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Disable a task"
    )

    @Argument(help: "Task name to disable")
    var name: String

    func run() throws {
        let store = ConfigStore()
        try store.updateTask(name: name) { task in
            task.enabled = false
        }

        let launchd = LaunchdManager()
        try launchd.unload(name: name)
        print("Disabled task '\(name)'")
    }
}
