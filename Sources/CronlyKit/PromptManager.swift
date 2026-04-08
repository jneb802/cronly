import Foundation

public final class PromptManager {
    public init() {}

    /// Extract the prompt string from a command's `-p "..."` flag
    public func extractPrompt(from command: String) -> String? {
        // Match -p "..." allowing escaped quotes inside
        guard let pRange = command.range(of: #"-p ""#) else { return nil }
        let afterFlag = command[pRange.upperBound...]

        var result = ""
        var escaped = false
        for ch in afterFlag {
            if escaped {
                result.append(ch)
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else if ch == "\"" {
                break
            } else {
                result.append(ch)
            }
        }
        return result.isEmpty ? nil : result
    }

    /// Write the prompt to a .md file and return the file URL
    public func writePromptFile(taskName: String, prompt: String) throws -> URL {
        try CronlyPaths.ensureDirectories()
        let fm = FileManager.default
        try fm.createDirectory(at: CronlyPaths.promptsDir, withIntermediateDirectories: true)

        let file = CronlyPaths.promptFile(name: taskName)
        try prompt.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    /// Get or create the prompt file for a task, returns the file URL
    public func promptFileURL(for task: TaskConfig) throws -> URL {
        let file = CronlyPaths.promptFile(name: task.name)
        let fm = FileManager.default

        if !fm.fileExists(atPath: file.path) {
            let prompt = extractPrompt(from: task.command) ?? task.command
            return try writePromptFile(taskName: task.name, prompt: prompt)
        }
        return file
    }
}
