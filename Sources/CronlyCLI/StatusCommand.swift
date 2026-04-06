import ArgumentParser
import CronlyKit

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show task status"
    )

    @Argument(help: "Task name (omit to show all)")
    var name: String?

    func run() throws {
        let store = ConfigStore()
        let config = try store.load()
        let launchd = LaunchdManager()
        let logReader = LogReader()

        let tasks: [TaskConfig]
        if let name {
            tasks = [try store.getTask(name: name)]
        } else {
            tasks = config.tasks
        }

        if tasks.isEmpty {
            print("No tasks configured.")
            return
        }

        for task in tasks {
            let loaded = launchd.isLoaded(name: task.name)
            let schedule = CronParser.describe(task.cronExpression)

            let stateStr: String
            if !task.enabled {
                stateStr = "\(ANSI.gray)disabled\(ANSI.reset)"
            } else if loaded {
                stateStr = "\(ANSI.green)active\(ANSI.reset)"
            } else {
                stateStr = "\(ANSI.yellow)not loaded\(ANSI.reset)"
            }

            print("\(task.name)")
            print("  State:    \(stateStr)")
            print("  Schedule: \(schedule) (\(task.cronExpression))")
            print("  Command:  \(task.command)")

            if let lastRun = logReader.lastRunTime(taskName: task.name) {
                let exitCode = logReader.lastExitCode(taskName: task.name) ?? -1
                let exitColor = exitCode == 0 ? ANSI.green : ANSI.red
                print("  Last run: \(lastRun) (exit: \(exitColor)\(exitCode)\(ANSI.reset))")
            } else {
                print("  Last run: never")
            }

            print()
        }
    }
}
