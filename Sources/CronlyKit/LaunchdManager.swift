import Foundation

public final class LaunchdManager {
    public init() {}

    /// Create and load a launchd plist for a task
    public func install(task: TaskConfig) throws {
        try CronlyPaths.ensureDirectories(taskName: task.name)

        let plist = try buildPlist(task: task)
        let plistURL = CronlyPaths.launchAgentPlist(name: task.name)

        // Unload first if already loaded
        unloadQuietly(name: task.name)

        try plist.write(to: plistURL, atomically: true, encoding: .utf8)

        if task.enabled {
            try load(name: task.name)
        }
    }

    /// Unload and remove the launchd plist
    public func uninstall(name: String) throws {
        unloadQuietly(name: name)

        let plistURL = CronlyPaths.launchAgentPlist(name: name)
        let fm = FileManager.default
        if fm.fileExists(atPath: plistURL.path) {
            try fm.removeItem(at: plistURL)
        }
    }

    /// Load (enable) a task's launchd job
    public func load(name: String) throws {
        let plistPath = CronlyPaths.launchAgentPlist(name: name).path
        let result = shell("launchctl", "load", plistPath)
        if result.status != 0 && !result.stderr.contains("already loaded") {
            throw CronlyError.launchdFailed("Failed to load \(name): \(result.stderr)")
        }
    }

    /// Unload (disable) a task's launchd job
    public func unload(name: String) throws {
        unloadQuietly(name: name)
    }

    /// Check if a job is currently loaded
    public func isLoaded(name: String) -> Bool {
        let label = CronlyPaths.launchAgentLabel(name: name)
        let result = shell("launchctl", "list", label)
        return result.status == 0
    }

    // MARK: - Private

    private func buildPlist(task: TaskConfig) throws -> String {
        let label = CronlyPaths.launchAgentLabel(name: task.name)
        let stdoutPath = CronlyPaths.taskStdoutLog(name: task.name).path
        let stderrPath = CronlyPaths.taskStderrLog(name: task.name).path
        let wrapperPath = CronlyPaths.taskLogsDir(name: task.name).appendingPathComponent("run.sh").path
        let historyDir = CronlyPaths.taskLogsDir(name: task.name).appendingPathComponent("history").path

        // Validate cron before writing any files
        let intervals = try CronParser.parse(task.cronExpression)

        // Create wrapper script that rotates logs and records run history
        let wrapper = """
        #!/bin/bash
        HISTORY_DIR="\(historyDir)"
        mkdir -p "$HISTORY_DIR"
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        RUN_DIR="$HISTORY_DIR/$TIMESTAMP"
        mkdir -p "$RUN_DIR"

        # Run the actual command, capturing output
        /bin/bash -l -c \(shellEscape(task.command)) > "$RUN_DIR/stdout.log" 2> "$RUN_DIR/stderr.log"
        EXIT_CODE=$?

        # Record metadata
        echo "$EXIT_CODE" > "$RUN_DIR/exit_code"
        echo "$(date -Iseconds)" > "$RUN_DIR/finished_at"

        # Also write to the main log files for quick access
        cp "$RUN_DIR/stdout.log" "\(stdoutPath)"
        cp "$RUN_DIR/stderr.log" "\(stderrPath)"

        # Signal the app that a job completed
        echo "\(task.name) $(date -Iseconds)" > "\(CronlyPaths.lastCompletedFile.path)"

        # Prune old runs (keep last 50)
        cd "$HISTORY_DIR" && ls -1t | tail -n +51 | xargs rm -rf 2>/dev/null

        exit $EXIT_CODE
        """

        let wrapperURL = URL(fileURLWithPath: wrapperPath)
        try wrapper.write(to: wrapperURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapperPath)

        var calendarXML = ""
        if intervals.count == 1 {
            calendarXML = "    <key>StartCalendarInterval</key>\n    <dict>\n"
            for (key, val) in intervals[0].sorted(by: { $0.key < $1.key }) {
                calendarXML += "        <key>\(key)</key>\n        <integer>\(val)</integer>\n"
            }
            calendarXML += "    </dict>"
        } else {
            calendarXML = "    <key>StartCalendarInterval</key>\n    <array>\n"
            for interval in intervals {
                calendarXML += "        <dict>\n"
                for (key, val) in interval.sorted(by: { $0.key < $1.key }) {
                    calendarXML += "            <key>\(key)</key>\n            <integer>\(val)</integer>\n"
                }
                calendarXML += "        </dict>\n"
            }
            calendarXML += "    </array>"
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(xmlEscape(label))</string>
            <key>ProgramArguments</key>
            <array>
                <string>/bin/bash</string>
                <string>\(xmlEscape(wrapperPath))</string>
            </array>
        \(calendarXML)
            <key>StandardOutPath</key>
            <string>\(xmlEscape(stdoutPath))</string>
            <key>StandardErrorPath</key>
            <string>\(xmlEscape(stderrPath))</string>
        </dict>
        </plist>
        """
    }

    private func shellEscape(_ command: String) -> String {
        "'" + command.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func xmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func unloadQuietly(name: String) {
        let label = CronlyPaths.launchAgentLabel(name: name)
        let _ = shell("launchctl", "bootout", "gui/\(getuid())/\(label)")
        let plistPath = CronlyPaths.launchAgentPlist(name: name).path
        let _ = shell("launchctl", "unload", plistPath)
    }

    private func shell(_ args: String...) -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (-1, "", error.localizedDescription)
        }

        let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, stdout, stderr)
    }
}
