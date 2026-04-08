import Foundation

public extension Notification.Name {
    static let cronlyJobCompleted = Notification.Name("cronlyJobCompleted")
}

public enum CronlyPaths {
    public static let configDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".cronly")
    }()

    public static let configFile: URL = {
        configDir.appendingPathComponent("config.json")
    }()

    public static let logsDir: URL = {
        configDir.appendingPathComponent("logs")
    }()

    public static let lastCompletedFile: URL = {
        configDir.appendingPathComponent("last_completed")
    }()

    public static let promptsDir: URL = {
        configDir.appendingPathComponent("prompts")
    }()

    public static func promptFile(name: String) -> URL {
        promptsDir.appendingPathComponent("\(name).md")
    }

    public static let launchAgentsDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents")
    }()

    public static func taskLogsDir(name: String) -> URL {
        logsDir.appendingPathComponent(name)
    }

    public static func taskStdoutLog(name: String) -> URL {
        taskLogsDir(name: name).appendingPathComponent("stdout.log")
    }

    public static func taskStderrLog(name: String) -> URL {
        taskLogsDir(name: name).appendingPathComponent("stderr.log")
    }

    public static func launchAgentPlist(name: String) -> URL {
        launchAgentsDir.appendingPathComponent("com.cronly.\(name).plist")
    }

    public static func launchAgentLabel(name: String) -> String {
        "com.cronly.\(name)"
    }

    public static func ensureDirectories(taskName: String? = nil) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: configDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: logsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: promptsDir, withIntermediateDirectories: true)
        if let taskName {
            try fm.createDirectory(at: taskLogsDir(name: taskName), withIntermediateDirectories: true)
        }
    }
}
