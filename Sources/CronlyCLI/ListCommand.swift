import ArgumentParser
import CronlyKit

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List all scheduled tasks"
    )

    @Flag(name: .long, help: "Show full command and last run details")
    var verbose: Bool = false

    func run() throws {
        let store = ConfigStore()
        let config = try store.load()

        if config.tasks.isEmpty {
            print("No tasks configured. Use 'cronly add' to create one.")
            return
        }

        let launchd = LaunchdManager()
        let logReader = LogReader()

        for task in config.tasks {
            let loaded = launchd.isLoaded(name: task.name)
            let statusIcon = task.enabled ? (loaded ? "●" : "○") : "○"
            let statusColor = task.enabled ? (loaded ? ANSI.green : ANSI.yellow) : ANSI.gray
            let schedule = CronParser.describe(task.cronExpression)

            print("\(statusColor)\(statusIcon)\(ANSI.reset) \(task.name)")
            print("  Schedule: \(schedule) (\(task.cronExpression))")

            if verbose {
                print("  Command:  \(task.command)")
                print("  Enabled:  \(task.enabled)")
                print("  Loaded:   \(loaded)")

                if let lastRun = logReader.lastRunTime(taskName: task.name) {
                    let exitCode = logReader.lastExitCode(taskName: task.name) ?? -1
                    let exitColor = exitCode == 0 ? ANSI.green : ANSI.red
                    print("  Last run: \(lastRun) (exit: \(exitColor)\(exitCode)\(ANSI.reset))")
                }
            }

            print()
        }
    }
}
