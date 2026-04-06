import ArgumentParser
import CronlyKit
import Foundation

struct Remove: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Remove a scheduled task"
    )

    @Argument(help: "Task name to remove")
    var name: String

    func run() throws {
        let launchd = LaunchdManager()
        try launchd.uninstall(name: name)

        let store = ConfigStore()
        try store.removeTask(name: name)

        // Clean up log directory
        let logsDir = CronlyPaths.taskLogsDir(name: name)
        try? FileManager.default.removeItem(at: logsDir)

        print("Removed task '\(name)'")
    }
}
