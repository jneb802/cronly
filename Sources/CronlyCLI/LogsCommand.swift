import ArgumentParser
import CronlyKit

struct Logs: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "View task output logs"
    )

    @Argument(help: "Task name")
    var name: String

    @Option(name: .long, help: "Number of past runs to show (default: 20)")
    var lines: Int = 20

    @Flag(name: .long, help: "Show only the most recent run")
    var last: Bool = false

    func run() throws {
        let store = ConfigStore()
        let _ = try store.getTask(name: name)

        let logReader = LogReader()
        let limit = last ? 1 : lines
        let runs = logReader.runs(taskName: name, limit: limit)

        if runs.isEmpty {
            print("No run history for '\(name)'")
            return
        }

        for record in runs {
            let exitColor = record.exitCode == 0 ? ANSI.green : ANSI.red
            let icon = record.exitCode == 0 ? "✓" : "✗"

            print("\(exitColor)\(icon)\(ANSI.reset) \(record.finishedAt) (exit: \(exitColor)\(record.exitCode)\(ANSI.reset))")

            if !record.stdout.isEmpty {
                let lines = record.stdout.split(separator: "\n", omittingEmptySubsequences: false)
                for line in lines.prefix(50) {
                    print("  \(line)")
                }
                if lines.count > 50 {
                    print("  ... (\(lines.count - 50) more lines)")
                }
            }

            if !record.stderr.isEmpty {
                print("  \(ANSI.red)stderr:\(ANSI.reset)")
                let lines = record.stderr.split(separator: "\n", omittingEmptySubsequences: false)
                for line in lines.prefix(20) {
                    print("  \(line)")
                }
            }

            print()
        }
    }
}
