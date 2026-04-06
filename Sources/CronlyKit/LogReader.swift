import Foundation

public struct RunRecord {
    public let timestamp: String
    public let exitCode: Int
    public let finishedAt: String
    public let stdout: String
    public let stderr: String
}

public final class LogReader {
    public init() {}

    /// Get past run records for a task, newest first
    public func runs(taskName: String, limit: Int = 20) -> [RunRecord] {
        let historyDir = CronlyPaths.taskLogsDir(name: taskName).appendingPathComponent("history")
        let fm = FileManager.default

        guard let entries = try? fm.contentsOfDirectory(atPath: historyDir.path) else {
            return []
        }

        let sorted = entries.sorted().reversed()
        return Array(sorted.prefix(limit)).compactMap { entry in
            let runDir = historyDir.appendingPathComponent(entry)
            let exitCode = (try? String(contentsOf: runDir.appendingPathComponent("exit_code"), encoding: .utf8))
                .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? -1
            let finishedAt = (try? String(contentsOf: runDir.appendingPathComponent("finished_at"), encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stdout = (try? String(contentsOf: runDir.appendingPathComponent("stdout.log"), encoding: .utf8)) ?? ""
            let stderr = (try? String(contentsOf: runDir.appendingPathComponent("stderr.log"), encoding: .utf8)) ?? ""

            return RunRecord(
                timestamp: entry,
                exitCode: exitCode,
                finishedAt: finishedAt,
                stdout: stdout,
                stderr: stderr
            )
        }
    }

    /// Get the most recent run's stdout
    public func lastOutput(taskName: String) -> String? {
        let runs = runs(taskName: taskName, limit: 1)
        return runs.first?.stdout
    }

    /// Get the most recent run's exit code
    public func lastExitCode(taskName: String) -> Int? {
        let runs = runs(taskName: taskName, limit: 1)
        return runs.first?.exitCode
    }

    /// Get the most recent run's timestamp
    public func lastRunTime(taskName: String) -> String? {
        let runs = runs(taskName: taskName, limit: 1)
        return runs.first?.finishedAt
    }
}
